class_name A1HazardGate
extends RefCounted

## A1-only preflight for hazard metadata and coverage, not a safety classifier,
## SDS substitute, trustworthy source proof, rights grant or shared wire DTO.
## A5 owns warning presentation; integrator owns ErrorEnvelope mapping.

const COMPLETENESS: Array[String] = [
	"not_assessed", "absent", "partial", "complete_for_declared_scope"
]
const FRESHNESS: Array[String] = ["current", "stale", "unknown"]
const CONFLICTS: Array[String] = ["none_reported", "conflicting", "not_assessed"]
const ORIGINS: Array[String] = ["external_reference", "user_reported"]
const ALLOWED_FIELDS: Array[String] = [
	"substance_ref", "completeness", "origin", "scope",
	"source", "assessed_at_utc", "reviewed_sections", "missing_sections",
	"absence_evidence_field", "statements", "freshness", "conflict_status"
]
const ALLOWED_STATEMENT_FIELDS: Array[String] = [
	"type", "code", "text", "source_field_locator"
]

static func assess(record: Variant, expected_substance_ref: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if not _valid_ref(expected_substance_ref):
		_flag(errors, "A1_HAZARD_EXPECTED_SUBSTANCE_INVALID")
	if record == null:
		warnings.append("A1_HAZARD_NOT_ASSESSED")
		return _result(errors, warnings, "not_assessed")

	if not record is Dictionary:
		_flag(errors, "A1_HAZARD_RECORD_INVALID")
		return _result(errors, warnings, "unavailable")

	for key in record:
		if not ALLOWED_FIELDS.has(key):
			_flag(errors, "A1_HAZARD_FIELD_UNSUPPORTED")

	var pinned: Variant = record.get("substance_ref")
	if not _valid_ref(pinned):
		_flag(errors, "A1_HAZARD_SUBSTANCE_UNRESOLVED")
	elif _valid_ref(expected_substance_ref) and pinned != expected_substance_ref:
		_flag(errors, "A1_HAZARD_SUBSTANCE_REVISION_MISMATCH")

	var state: Variant = record.get("completeness")
	if not COMPLETENESS.has(state):
		_flag(errors, "A1_HAZARD_COMPLETENESS_INVALID")

	var fresh: Variant = record.get("freshness")
	if not FRESHNESS.has(fresh):
		_flag(errors, "A1_HAZARD_FRESHNESS_UNDECLARED")
	elif fresh == "stale":
		warnings.append("A1_HAZARD_STALE")
	elif fresh == "unknown":
		warnings.append("A1_HAZARD_FRESHNESS_UNKNOWN")

	var conflict: Variant = record.get("conflict_status")
	if not CONFLICTS.has(conflict):
		_flag(errors, "A1_HAZARD_CONFLICT_UNDECLARED")
	elif conflict == "conflicting":
		warnings.append("A1_HAZARD_CONFLICTING_SOURCES")
	elif conflict == "not_assessed":
		warnings.append("A1_HAZARD_CONFLICT_NOT_ASSESSED")

	var reviewed: Variant = record.get("reviewed_sections")
	var missing: Variant = record.get("missing_sections")
	var statements: Variant = record.get("statements")
	var sections_ok: bool = reviewed is Array and missing is Array
	if not sections_ok:
		_flag(errors, "A1_HAZARD_SECTIONS_INVALID")
	if not statements is Array:
		_flag(errors, "A1_HAZARD_STATEMENTS_INVALID")

	if state == "not_assessed":
		# No classifier/scope or hazard assertion can be manufactured from an
		# unassessed draft; unknown is different from evidenced "absent".
		if record.get("source") != null or record.get("scope") != null:
			_flag(errors, "A1_HAZARD_UNASSESSED_CONTRADICTION")
		if record.get("assessed_at_utc") != null or record.get("absence_evidence_field") != null:
			_flag(errors, "A1_HAZARD_UNASSESSED_CONTRADICTION")
		if sections_ok and (not reviewed.is_empty() or not missing.is_empty()):
			_flag(errors, "A1_HAZARD_UNASSESSED_CONTRADICTION")
		if statements is Array and not statements.is_empty():
			_flag(errors, "A1_HAZARD_UNASSESSED_CONTRADICTION")
		if fresh != "unknown" or conflict != "not_assessed":
			_flag(errors, "A1_HAZARD_UNASSESSED_CONTRADICTION")
		warnings.append("A1_HAZARD_NOT_ASSESSED")
		return _result(errors, warnings, state)

	if not COMPLETENESS.has(state):
		return _result(errors, warnings, "unavailable")

	# A scoped assessment must declare a source, provenance and boundaries.
	if not ORIGINS.has(record.get("origin")):
		_flag(errors, "A1_HAZARD_ORIGIN_INVALID")
	var scope: Variant = record.get("scope")
	var source: Variant = record.get("source")
	var declared: Variant = null
	if not scope is Dictionary:
		_flag(errors, "A1_HAZARD_SCOPE_INCOMPLETE")
	else:
		for key in ["framework", "framework_version", "jurisdiction"]:
			if not _nonempty(scope.get(key)):
				_flag(errors, "A1_HAZARD_SCOPE_INCOMPLETE")
		if scope.size() != 4:
			_flag(errors, "A1_HAZARD_SCOPE_INCOMPLETE")
		declared = scope.get("declared_sections")
		if not _distinct_sections(declared):
			_flag(errors, "A1_HAZARD_SCOPE_INCOMPLETE")

	if not source is Dictionary:
		_flag(errors, "A1_HAZARD_SOURCE_INCOMPLETE")
	else:
		if source.size() != 4:
			_flag(errors, "A1_HAZARD_SOURCE_INCOMPLETE")
		for key in ["source_id", "source_version", "record_locator", "retrieved_at_utc"]:
			if not _nonempty(source.get(key)):
				_flag(errors, "A1_HAZARD_SOURCE_INCOMPLETE")
	if not _nonempty(record.get("assessed_at_utc")):
		_flag(errors, "A1_HAZARD_ASSESSMENT_DATE_MISSING")

	if sections_ok:
		if not _distinct_sections(reviewed, false) or not _distinct_sections(missing, false):
			_flag(errors, "A1_HAZARD_SECTIONS_INVALID")
		if declared is Array and _distinct_sections(declared):
			var union: Dictionary = {}
			for section in reviewed:
				union[section] = true
			for section in missing:
				if union.has(section):
					_flag(errors, "A1_HAZARD_SECTION_CONFLICT")
				union[section] = true
			if union.size() != declared.size():
				_flag(errors, "A1_HAZARD_SECTION_COVERAGE_INCOMPLETE")
			for section in declared:
				if not union.has(section):
					_flag(errors, "A1_HAZARD_SECTION_COVERAGE_INCOMPLETE")
		if state == "partial" and (reviewed.is_empty() or missing.is_empty()):
			_flag(errors, "A1_HAZARD_PARTIAL_COVERAGE_INVALID")
		if state in ["absent", "complete_for_declared_scope"] and (
				reviewed.is_empty() or not missing.is_empty()):
			_flag(errors, "A1_HAZARD_COVERAGE_MISMATCH")

	if statements is Array:
		var statement_keys: Dictionary = {}
		for statement in statements:
			if not statement is Dictionary:
				_flag(errors, "A1_HAZARD_STATEMENT_INVALID")
				continue
			for key in statement:
				if not ALLOWED_STATEMENT_FIELDS.has(key):
					_flag(errors, "A1_HAZARD_STATEMENT_INVALID")
			var kind: Variant = statement.get("type")
			var code: Variant = statement.get("code")
			if kind not in ["H", "P"] or not _nonempty(code) or not _nonempty(statement.get("text")) or not _nonempty(statement.get("source_field_locator")):
				_flag(errors, "A1_HAZARD_STATEMENT_INVALID")
				continue
			if not code.begins_with(kind):
				_flag(errors, "A1_HAZARD_STATEMENT_INVALID")
			var unique_key: String = kind + "/" + code
			if statement_keys.has(unique_key):
				_flag(errors, "A1_HAZARD_STATEMENT_DUPLICATE")
			statement_keys[unique_key] = true

	if state == "absent":
		if not _nonempty(record.get("absence_evidence_field")):
			_flag(errors, "A1_HAZARD_ABSENCE_UNEVIDENCED")
		if statements is Array and not statements.is_empty():
			_flag(errors, "A1_HAZARD_ABSENCE_CONTRADICTION")
		warnings.append("A1_HAZARD_SCOPED_RECORD_ABSENT")
	elif state == "partial":
		if record.get("absence_evidence_field") != null:
			_flag(errors, "A1_HAZARD_ABSENCE_CONTRADICTION")
		warnings.append("A1_HAZARD_PARTIAL_COVERAGE")
	elif state == "complete_for_declared_scope":
		if record.get("absence_evidence_field") != null:
			_flag(errors, "A1_HAZARD_ABSENCE_CONTRADICTION")
		warnings.append("A1_HAZARD_SCOPE_ONLY_NOT_SAFETY_PROOF")

	return _result(errors, warnings, state)


static func _result(errors: Array[String], warnings: Array[String], state: String) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"completeness": state,
		"safety_assurance": false,
		"scope": "a1_hazard_metadata_preflight_only"
	}


static func _distinct_sections(sections: Variant, require_nonempty: bool = true) -> bool:
	if not sections is Array:
		return false
	if require_nonempty and sections.is_empty():
		return false
	var seen: Dictionary = {}
	for item in sections:
		if not _nonempty(item) or seen.has(item):
			return false
		seen[item] = true
	return true


static func _valid_ref(ref: Variant) -> bool:
	return ref is Dictionary and ref.size() == 2 and _nonempty(ref.get("id")) and _positive_int(ref.get("record_revision"))


static func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0


static func _nonempty(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


static func _flag(errors: Array[String], code: String) -> void:
	if not errors.has(code):
		errors.append(code)
