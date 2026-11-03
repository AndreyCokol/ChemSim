class_name A1UserCatalog
extends RefCounted

## A1 local draft catalog format, NOT an interchange DTO or reference dataset.
## The caller assigns durable IDs; A2 owns validated chemistry; A5 owns UI drafts.
## No imported scientific constant is ever admitted by storing a user draft.

const SCHEMA_VERSION: int = 1
const MAX_RECORDS: int = 2000
const MAX_BYTES: int = 2000000
const MAX_PROPERTIES: int = 64
const STORE_PATH: String = "user://a1_substance_drafts_v1.json"
const TEST_PATH: String = "user://a1_substance_drafts_test_v1.json"
const DRAFT_ORIGINS: Array[String] = ["user_defined", "hypothetical"]
const VALUE_STATES: Array[String] = ["present", "unknown", "not_reported", "not_applicable", "withheld"]
const RECORD_FIELDS: Array[String] = [
	"substance_id", "record_revision", "origin", "identity_status",
	"formula_ast_ref", "display_name", "provenance", "properties",
	"hazard_completeness"
]
const PROPERTY_FIELDS: Array[String] = [
	"property_id", "value_state", "value", "unit_id", "basis", "origin", "quality"
]

static func empty_document() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "records": []}


static func validate_record(record: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not record is Dictionary:
		return _failure("A1_CATALOG_RECORD_INVALID")
	for key in record:
		if not RECORD_FIELDS.has(key):
			_add(errors, "A1_CATALOG_FIELD_UNSUPPORTED")
	if not _nonempty(record.get("substance_id")) or not _positive_int(record.get("record_revision")):
		_add(errors, "A1_CATALOG_IDENTITY_INVALID")
	if not DRAFT_ORIGINS.has(record.get("origin")):
		_add(errors, "A1_CATALOG_ORIGIN_UNSUPPORTED")
	# Until an authenticated A2 adapter exists, user drafts remain unresolved.
	if record.get("identity_status") != "incomplete":
		_add(errors, "A1_CATALOG_IDENTITY_PROMOTION_BLOCKED")
	if typeof(record.get("display_name")) != TYPE_STRING:
		_add(errors, "A1_CATALOG_NAME_INVALID")
	elif record["display_name"].length() > 512:
		_add(errors, "A1_CATALOG_NAME_INVALID")
	var ast_ref: Variant = record.get("formula_ast_ref")
	if ast_ref != null and not _valid_ref(ast_ref):
		_add(errors, "A1_CATALOG_AST_REF_INVALID")
	var provenance: Variant = record.get("provenance")
	if not provenance is Dictionary:
		_add(errors, "A1_CATALOG_PROVENANCE_INVALID")
	else:
		if provenance.size() != 3:
			_add(errors, "A1_CATALOG_PROVENANCE_INVALID")
		for key in provenance:
			if not ["kind", "created_at_utc", "updated_at_utc"].has(key):
				_add(errors, "A1_CATALOG_PROVENANCE_INVALID")
		if provenance.get("kind") != "local_user_input":
			_add(errors, "A1_CATALOG_PROVENANCE_INVALID")
		if not _nonempty(provenance.get("created_at_utc")) or not _nonempty(provenance.get("updated_at_utc")):
			_add(errors, "A1_CATALOG_PROVENANCE_INVALID")
	if record.get("hazard_completeness") != "not_assessed":
		_add(errors, "A1_CATALOG_HAZARD_PROMOTION_BLOCKED")
	var properties: Variant = record.get("properties")
	if not properties is Array:
		_add(errors, "A1_CATALOG_PROPERTIES_INVALID")
	elif properties.size() > MAX_PROPERTIES:
		_add(errors, "A1_CATALOG_TOO_MANY_PROPERTIES")
	else:
		var seen: Dictionary = {}
		for property in properties:
			_inspect_property(property, record.get("origin"), errors)
			if property is Dictionary and _nonempty(property.get("property_id")):
				if seen.has(property["property_id"]):
					_add(errors, "A1_CATALOG_PROPERTY_DUPLICATE")
				seen[property["property_id"]] = true
	return {"ok": errors.is_empty(), "errors": errors}


static func validate_document(document: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not document is Dictionary:
		return _failure("A1_CATALOG_DOCUMENT_INVALID")
	if document.size() != 2 or not document.has("schema_version") or not document.has("records"):
		_add(errors, "A1_CATALOG_DOCUMENT_INVALID")
	if typeof(document.get("schema_version")) != TYPE_INT or document.get("schema_version") != SCHEMA_VERSION:
		_add(errors, "A1_CATALOG_VERSION_UNSUPPORTED")
	var rows: Variant = document.get("records")
	if not rows is Array:
		_add(errors, "A1_CATALOG_DOCUMENT_INVALID")
		return {"ok": false, "errors": errors}
	if rows.size() > MAX_RECORDS:
		_add(errors, "A1_CATALOG_TOO_MANY_RECORDS")
	var latest: Dictionary = {}
	for row in rows:
		var row_check: Dictionary = validate_record(row)
		for error_code in row_check["errors"]:
			_add(errors, error_code)
		if not row is Dictionary or not _nonempty(row.get("substance_id")) or not _positive_int(row.get("record_revision")):
			continue
		var id: String = row["substance_id"]
		var old: Variant = latest.get(id)
		if old == null:
			if row["record_revision"] != 1:
				_add(errors, "A1_CATALOG_REVISION_SEQUENCE_INVALID")
		else:
			if row["record_revision"] != old["record_revision"] + 1:
				_add(errors, "A1_CATALOG_REVISION_SEQUENCE_INVALID")
			if not _immutable_identity_equal(old, row):
				_add(errors, "A1_CATALOG_IDENTITY_MUTATION_BLOCKED")
		latest[id] = row
	return {"ok": errors.is_empty(), "errors": errors}


static func append_draft(document: Dictionary, draft: Dictionary, expected_previous_revision: int) -> Dictionary:
	var errors: Array[String] = []
	var checked: Dictionary = validate_document(document)
	if not checked["ok"]:
		return {"ok": false, "errors": checked["errors"], "document": document.duplicate(true)}
	var draft_check: Dictionary = validate_record(draft)
	if not draft_check["ok"]:
		return {"ok": false, "errors": draft_check["errors"], "document": document.duplicate(true)}
	if expected_previous_revision < 0:
		_add(errors, "A1_CATALOG_REVISION_CONFLICT")
	var latest: Variant = null
	for row in document["records"]:
		if row["substance_id"] == draft["substance_id"]:
			latest = row
	if latest == null:
		if expected_previous_revision != 0 or draft["record_revision"] != 1:
			_add(errors, "A1_CATALOG_REVISION_CONFLICT")
	else:
		if latest["record_revision"] != expected_previous_revision or draft["record_revision"] != expected_previous_revision + 1:
			_add(errors, "A1_CATALOG_REVISION_CONFLICT")
		if not _immutable_identity_equal(latest, draft):
			_add(errors, "A1_CATALOG_IDENTITY_MUTATION_BLOCKED")
	if document["records"].size() >= MAX_RECORDS:
		_add(errors, "A1_CATALOG_TOO_MANY_RECORDS")
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "document": document.duplicate(true)}
	var next_document: Dictionary = document.duplicate(true)
	next_document["records"].append(draft.duplicate(true))
	var final_check: Dictionary = validate_document(next_document)
	if not final_check["ok"]:
		return {"ok": false, "errors": final_check["errors"], "document": document.duplicate(true)}
	return {"ok": true, "errors": [], "document": next_document}


static func serialize_document(document: Dictionary) -> Dictionary:
	var check: Dictionary = validate_document(document)
	if not check["ok"]:
		return {"ok": false, "errors": check["errors"]}
	var serialized: String = JSON.stringify(document)
	if serialized.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("A1_CATALOG_TOO_LARGE")
	return {"ok": true, "errors": [], "json": serialized}


static func deserialize_document(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("A1_CATALOG_TOO_LARGE")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _failure("A1_CATALOG_JSON_INVALID")
	var data: Variant = parser.data
	var check: Dictionary = validate_document(data)
	if not check["ok"]:
		return {"ok": false, "errors": check["errors"]}
	return {"ok": true, "errors": [], "document": data}


static func save_local(document: Dictionary, test_mode: bool = false) -> Dictionary:
	var packed: Dictionary = serialize_document(document)
	if not packed["ok"]:
		return packed
	var destination: String = TEST_PATH if test_mode else STORE_PATH
	var temporary: String = destination + ".tmp"
	var backup: String = destination + ".bak"
	var handle: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		return _failure("A1_CATALOG_WRITE_FAILED")
	handle.store_string(packed["json"])
	handle.flush()
	handle.close()
	# Re-parse the staged bytes before touching the previous snapshot.
	var staged: Dictionary = load_local_from_path(temporary)
	if not staged["ok"] or staged["document"] != document:
		return _failure("A1_CATALOG_STAGING_FAILED")
	var source_full: String = ProjectSettings.globalize_path(destination)
	var temp_full: String = ProjectSettings.globalize_path(temporary)
	var backup_full: String = ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(destination):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup_full) != OK:
			return _failure("A1_CATALOG_BACKUP_FAILED")
		if DirAccess.rename_absolute(source_full, backup_full) != OK:
			return _failure("A1_CATALOG_BACKUP_FAILED")
	if DirAccess.rename_absolute(temp_full, source_full) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup_full, source_full)
		return _failure("A1_CATALOG_WRITE_FAILED")
	# Retain backup for explicit recovery; never silently load a stale backup.
	return {"ok": true, "errors": [], "path": destination}


static func load_local(test_mode: bool = false) -> Dictionary:
	return load_local_from_path(TEST_PATH if test_mode else STORE_PATH)


static func load_local_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("A1_CATALOG_FILE_MISSING")
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return _failure("A1_CATALOG_READ_FAILED")
	if handle.get_length() > MAX_BYTES:
		handle.close()
		return _failure("A1_CATALOG_TOO_LARGE")
	var source: String = handle.get_as_text()
	handle.close()
	return deserialize_document(source)


static func _inspect_property(property: Variant, record_origin: Variant, errors: Array[String]) -> void:
	if not property is Dictionary:
		_add(errors, "A1_CATALOG_PROPERTY_INVALID")
		return
	for key in property:
		if not PROPERTY_FIELDS.has(key):
			_add(errors, "A1_CATALOG_PROPERTY_INVALID")
	if not _nonempty(property.get("property_id")) or property.get("origin") != record_origin:
		_add(errors, "A1_CATALOG_PROPERTY_INVALID")
	if property.get("quality") != "unverified":
		_add(errors, "A1_CATALOG_PROPERTY_PROMOTION_BLOCKED")
	var state: Variant = property.get("value_state")
	if not VALUE_STATES.has(state):
		_add(errors, "A1_CATALOG_VALUE_STATE_INVALID")
	elif state == "present":
		var value: Variant = property.get("value")
		if not _finite_number(value) or not _nonempty(property.get("unit_id")) or not _nonempty(property.get("basis")):
			_add(errors, "A1_CATALOG_PRESENT_VALUE_INVALID")
	else:
		if property.has("value"):
			_add(errors, "A1_CATALOG_MISSING_VALUE_IS_NOT_ZERO")


static func _immutable_identity_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.get("origin") != b.get("origin"):
		return false
	if a.get("formula_ast_ref") != b.get("formula_ast_ref"):
		return false
	var ap: Variant = a.get("provenance")
	var bp: Variant = b.get("provenance")
	return ap is Dictionary and bp is Dictionary and ap.get("created_at_utc") == bp.get("created_at_utc")


static func _valid_ref(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and _nonempty(value.get("id")) and _positive_int(value.get("record_revision"))


static func _nonempty(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


static func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))


static func _add(errors: Array[String], code: String) -> void:
	if not errors.has(code):
		errors.append(code)


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "errors": [code]}
