extends SceneTree

## All records are synthetic/local-only. No scientific constants or rights asserted.
const Catalog = preload("res://src/chemistry/a1/a1_user_catalog.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_incomplete_user_and_hypothetical_records()
	_test_revision_conflict_and_immutable_identity()
	_test_unknown_vs_explicit_zero_properties()
	_test_provenance_and_false_promotion()
	_test_snapshot_version_and_json_guards()
	_test_real_file_round_trip()
	if failures.is_empty():
		print("PASS: A1 local draft catalog revisions, provenance and disk round-trip")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _draft(id: String = "user-test-01", origin: String = "user_defined") -> Dictionary:
	return {
		"substance_id": id,
		"record_revision": 1,
		"origin": origin,
		"identity_status": "incomplete",
		"formula_ast_ref": null,
		"display_name": "Synthetic draft",
		"provenance": {
			"kind": "local_user_input",
			"created_at_utc": "2026-11-03T15:00:00Z",
			"updated_at_utc": "2026-11-03T15:00:00Z"
		},
		"properties": [],
		"hazard_completeness": "not_assessed"
	}


func _test_incomplete_user_and_hypothetical_records() -> void:
	var empty: Dictionary = Catalog.empty_document()
	_ok(Catalog.validate_document(empty), "empty local catalog valid")
	var base: Dictionary = _draft()
	_ok(Catalog.validate_record(base), "incomplete user draft is storable")
	var added: Dictionary = Catalog.append_draft(empty, base, 0)
	_ok(added, "first revision append")
	_expect(empty["records"].is_empty(), "append cannot mutate caller document")
	_expect(added["document"]["records"].size() == 1, "first revision persisted in returned document")
	var hypothetical: Dictionary = _draft("hypothetical-test-01", "hypothetical")
	var with_hypo: Dictionary = Catalog.append_draft(added["document"], hypothetical, 0)
	_ok(with_hypo, "separate hypothetical identity is storable")
	_expect(with_hypo["document"]["records"][1]["origin"] == "hypothetical", "hypothetical origin preserved exactly")
	_expect(with_hypo["document"]["records"][1]["hazard_completeness"] == "not_assessed", "missing hazard info not safe")
	var missing_ast: Dictionary = base.duplicate(true)
	missing_ast["formula_ast_ref"] = {"id": "selected-AST", "record_revision": 1}
	_ok(Catalog.validate_record(missing_ast), "untrusted AST link can be stored as incomplete only")
	missing_ast["identity_status"] = "validated"
	_code(Catalog.validate_record(missing_ast), "A1_CATALOG_IDENTITY_PROMOTION_BLOCKED", "catalog cannot self-certify A2 formula")


func _test_revision_conflict_and_immutable_identity() -> void:
	var doc: Dictionary = Catalog.append_draft(Catalog.empty_document(), _draft(), 0)["document"]
	var next: Dictionary = _draft()
	next["record_revision"] = 2
	next["display_name"] = "Updated local label"
	next["provenance"]["updated_at_utc"] = "2026-11-03T16:00:00Z"
	var appended: Dictionary = Catalog.append_draft(doc, next, 1)
	_ok(appended, "append second revision")
	_expect(doc["records"].size() == 1, "historical snapshot is immutable by append")
	_expect(appended["document"]["records"][0]["display_name"] == "Synthetic draft", "old revision preserved")
	_expect(appended["document"]["records"][1]["display_name"] == "Updated local label", "new revision stored separately")
	_code(Catalog.append_draft(doc, next, 0), "A1_CATALOG_REVISION_CONFLICT", "wrong optimistic revision")
	_code(Catalog.append_draft(appended["document"], next, 1), "A1_CATALOG_REVISION_CONFLICT", "replayed revision")
	var skipped: Dictionary = next.duplicate(true)
	skipped["record_revision"] = 4
	_code(Catalog.append_draft(doc, skipped, 1), "A1_CATALOG_REVISION_CONFLICT", "cannot skip revisions")
	var origin_flip: Dictionary = next.duplicate(true)
	origin_flip["origin"] = "hypothetical"
	_code(Catalog.append_draft(doc, origin_flip, 1), "A1_CATALOG_IDENTITY_MUTATION_BLOCKED", "cannot change immutable origin")
	var changed_ast: Dictionary = next.duplicate(true)
	changed_ast["formula_ast_ref"] = {"id": "other-ast", "record_revision": 1}
	_code(Catalog.append_draft(doc, changed_ast, 1), "A1_CATALOG_IDENTITY_MUTATION_BLOCKED", "AST change requires new identity")
	var changed_birth: Dictionary = next.duplicate(true)
	changed_birth["provenance"]["created_at_utc"] = "2026-11-03T17:00:00Z"
	_code(Catalog.append_draft(doc, changed_birth, 1), "A1_CATALOG_IDENTITY_MUTATION_BLOCKED", "creation time immutable")


func _test_unknown_vs_explicit_zero_properties() -> void:
	var record: Dictionary = _draft()
	record["properties"] = [{
		"property_id": "synthetic_test_property",
		"value_state": "unknown",
		"origin": "user_defined",
		"quality": "unverified"
	}]
	_ok(Catalog.validate_record(record), "unknown property stored without value")
	var copied: Dictionary = record.duplicate(true)
	var p: Dictionary = copied["properties"][0]
	p["value"] = 0.0
	_code(Catalog.validate_record(copied), "A1_CATALOG_MISSING_VALUE_IS_NOT_ZERO", "unknown cannot masquerade as present zero")
	p["value_state"] = "present"
	p["unit_id"] = "1"
	p["basis"] = "synthetic_test_basis"
	_ok(Catalog.validate_record(copied), "explicit present zero can be stored as unverified user input")
	p["value"] = true
	_code(Catalog.validate_record(copied), "A1_CATALOG_PRESENT_VALUE_INVALID", "boolean not a number")
	p["value"] = NAN
	_code(Catalog.validate_record(copied), "A1_CATALOG_PRESENT_VALUE_INVALID", "NaN cannot enter JSON catalog")
	p["value"] = INF
	_code(Catalog.validate_record(copied), "A1_CATALOG_PRESENT_VALUE_INVALID", "infinity cannot enter JSON catalog")
	p["value"] = "0"
	_code(Catalog.validate_record(copied), "A1_CATALOG_PRESENT_VALUE_INVALID", "string number not numeric")
	p["value"] = 0.0
	p["quality"] = "verified"
	_code(Catalog.validate_record(copied), "A1_CATALOG_PROPERTY_PROMOTION_BLOCKED", "local value cannot be promoted to verified")
	p["quality"] = "unverified"
	p["origin"] = "curated_reference"
	_code(Catalog.validate_record(copied), "A1_CATALOG_PROPERTY_INVALID", "local property cannot impersonate reference")
	p["origin"] = "user_defined"
	copied["properties"].append(p.duplicate(true))
	_code(Catalog.validate_record(copied), "A1_CATALOG_PROPERTY_DUPLICATE", "duplicate property assertion in a revision")


func _test_provenance_and_false_promotion() -> void:
	var invalid: Dictionary = _draft()
	invalid["origin"] = "curated_reference"
	_code(Catalog.validate_record(invalid), "A1_CATALOG_ORIGIN_UNSUPPORTED", "cannot import curated record into user drafts")
	invalid = _draft()
	invalid["hazard_completeness"] = "complete_for_declared_scope"
	_code(Catalog.validate_record(invalid), "A1_CATALOG_HAZARD_PROMOTION_BLOCKED", "hazard status not inferred from empty report")
	invalid = _draft()
	invalid["formal_charge"] = 0
	_code(Catalog.validate_record(invalid), "A1_CATALOG_FIELD_UNSUPPORTED", "A2 charge truth cannot be duplicated")
	invalid = _draft()
	invalid["phase"] = "aq"
	_code(Catalog.validate_record(invalid), "A1_CATALOG_FIELD_UNSUPPORTED", "substance identity cannot store phase")
	invalid = _draft()
	invalid["model_eligibility"] = "accepted"
	_code(Catalog.validate_record(invalid), "A1_CATALOG_FIELD_UNSUPPORTED", "no model suitability promotion")
	invalid = _draft()
	invalid["redistribution"] = "approved_for_redistribution"
	_code(Catalog.validate_record(invalid), "A1_CATALOG_FIELD_UNSUPPORTED", "no redistribution promotion")
	invalid = _draft()
	invalid["provenance"].erase("kind")
	_code(Catalog.validate_record(invalid), "A1_CATALOG_PROVENANCE_INVALID", "source kind required")


func _test_snapshot_version_and_json_guards() -> void:
	var doc: Dictionary = Catalog.append_draft(Catalog.empty_document(), _draft(), 0)["document"]
	var encoded: Dictionary = Catalog.serialize_document(doc)
	_ok(encoded, "serialize valid catalog")
	var decoded: Dictionary = Catalog.deserialize_document(encoded["json"])
	_ok(decoded, "deserialize valid catalog")
	_expect(decoded["document"] == doc, "round-trip preserves exact record and metadata")
	_code(Catalog.deserialize_document("{oops"), "A1_CATALOG_JSON_INVALID", "malformed JSON")
	var future: Dictionary = doc.duplicate(true)
	future["schema_version"] = 2
	_code(Catalog.serialize_document(future), "A1_CATALOG_VERSION_UNSUPPORTED", "unknown schema is not auto-migrated")
	var malformed: Dictionary = doc.duplicate(true)
	malformed["records"][0]["record_revision"] = 2
	_code(Catalog.validate_document(malformed), "A1_CATALOG_REVISION_SEQUENCE_INVALID", "snapshot missing revision 1")
	var doubled: Dictionary = doc.duplicate(true)
	doubled["records"].append(doubled["records"][0].duplicate(true))
	_code(Catalog.validate_document(doubled), "A1_CATALOG_REVISION_SEQUENCE_INVALID", "duplicate revision not tolerated")
	var injected: Dictionary = doc.duplicate(true)
	injected["unrecognized_field"] = "ignored-no-more"
	_code(Catalog.validate_document(injected), "A1_CATALOG_DOCUMENT_INVALID", "unknown document field not silently dropped")


func _test_real_file_round_trip() -> void:
	var path: String = Catalog.TEST_PATH
	var backup_path: String = path + ".bak"
	for candidate in [path, backup_path, path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	var first: Dictionary = Catalog.append_draft(Catalog.empty_document(), _draft(), 0)["document"]
	var saved: Dictionary = Catalog.save_local(first, true)
	_ok(saved, "actual user:// test catalog write")
	var loaded: Dictionary = Catalog.load_local(true)
	_ok(loaded, "actual user:// test catalog read")
	_expect(loaded["document"] == first, "disk bytes preserve draft")
	var revised: Dictionary = _draft()
	revised["record_revision"] = 2
	revised["display_name"] = "Second revision"
	revised["provenance"]["updated_at_utc"] = "2026-11-03T17:00:00Z"
	var second: Dictionary = Catalog.append_draft(first, revised, 1)["document"]
	_ok(Catalog.save_local(second, true), "second disk write with existing file")
	_expect(FileAccess.file_exists(backup_path), "previous known-good snapshot retained as backup")
	_expect(Catalog.load_local(true)["document"] == second, "latest valid snapshot loaded")
	var corrupt: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if corrupt == null:
		_expect(false, "test can deliberately corrupt only dedicated test file")
	else:
		corrupt.store_string("broken-json")
		corrupt.close()
	_code(Catalog.load_local(true), "A1_CATALOG_JSON_INVALID", "corrupt main file must fail closed, not import stale backup silently")
	for candidate in [path, backup_path, path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _ok(result: Dictionary, description: String) -> void:
	_expect(result.get("ok", false) == true, description + "; got " + str(result.get("errors", [])))


func _code(result: Dictionary, expected: String, description: String) -> void:
	_expect(result.get("ok", true) == false and result.get("errors", []).has(expected),
		description + "; expected " + expected + "; got " + str(result.get("errors", [])))


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
