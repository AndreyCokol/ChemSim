extends SceneTree

## All hazard statements and source locators are synthetic metadata, not SDS.
const Gate = preload("res://src/chemistry/a1/a1_hazard_gate.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_unknown_never_means_safe()
	_test_scoped_partial_coverage()
	_test_complete_is_not_universal_safety()
	_test_absent_requires_evidence()
	_test_subject_source_and_scope_validation()
	_test_h_and_p_statement_provenance()
	_test_freshness_and_conflicts_are_independent()
	if failures.is_empty():
		print("PASS: A1 scoped hazard completeness and source metadata gates")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _ref() -> Dictionary:
	return {"id": "synthetic-substance-hazard", "record_revision": 7}


func _record() -> Dictionary:
	return {
		"substance_ref": _ref(),
		"completeness": "partial",
		"origin": "external_reference",
		"scope": {
			"framework": "synthetic-ghs-style",
			"framework_version": "test-v1",
			"jurisdiction": "synthetic-test-jurisdiction",
			"declared_sections": ["classification", "labeling", "handling"]
		},
		"source": {
			"source_id": "synthetic-document",
			"source_version": "test-v1",
			"record_locator": "local-test/record",
			"retrieved_at_utc": "2026-11-03T00:00:00Z"
		},
		"assessed_at_utc": "2026-11-03T12:00:00Z",
		"reviewed_sections": ["classification", "labeling"],
		"missing_sections": ["handling"],
		"absence_evidence_field": null,
		"statements": [{
			"type": "H", "code": "H-TEST", "text": "Synthetic warning, not chemical safety advice",
			"source_field_locator": "synthetic-document/field-H"
		}],
		"freshness": "unknown",
		"conflict_status": "not_assessed"
	}


func _test_unknown_never_means_safe() -> void:
	var result: Dictionary = Gate.assess(null, _ref())
	_ok(result, "missing hazard record is displayable as unknown")
	_expect(result["completeness"] == "not_assessed", "missing record must be not_assessed")
	_expect(result["warnings"].has("A1_HAZARD_NOT_ASSESSED"), "missing record announces lack of assessment")
	_expect(result["safety_assurance"] == false, "no hazard record never means safe")
	var unassessed: Dictionary = {
		"substance_ref": _ref(),
		"completeness": "not_assessed",
		"origin": "user_reported",
		"scope": null, "source": null, "assessed_at_utc": null,
		"reviewed_sections": [], "missing_sections": [],
		"absence_evidence_field": null, "statements": [],
		"freshness": "unknown", "conflict_status": "not_assessed"
	}
	_ok(Gate.assess(unassessed, _ref()), "explicit unassessed record allowed")
	var falsely_scoped: Dictionary = unassessed.duplicate(true)
	falsely_scoped["scope"] = _record()["scope"]
	_code(Gate.assess(falsely_scoped, _ref()), "A1_HAZARD_UNASSESSED_CONTRADICTION", "cannot smuggle positive scope into unassessed record")
	var declared_safe: Dictionary = unassessed.duplicate(true)
	declared_safe["safe"] = true
	_code(Gate.assess(declared_safe, _ref()), "A1_HAZARD_FIELD_UNSUPPORTED", "no safety verdict field")
	_code(Gate.assess(null, {"id": "", "record_revision": 0}), "A1_HAZARD_EXPECTED_SUBSTANCE_INVALID", "caller must supply versioned identity")


func _test_scoped_partial_coverage() -> void:
	var partial: Dictionary = _record()
	var answer: Dictionary = Gate.assess(partial, _ref())
	_ok(answer, "synthetic partial assessment with reviewed/missing sections")
	_expect(answer["warnings"].has("A1_HAZARD_PARTIAL_COVERAGE"), "partial must warn")
	_expect(answer["safety_assurance"] == false, "partial cannot certify safe")
	var no_missing: Dictionary = partial.duplicate(true)
	no_missing["missing_sections"] = []
	_code(Gate.assess(no_missing, _ref()), "A1_HAZARD_PARTIAL_COVERAGE_INVALID", "partial must declare missing sections")
	var overlap: Dictionary = partial.duplicate(true)
	overlap["missing_sections"].append("classification")
	_code(Gate.assess(overlap, _ref()), "A1_HAZARD_SECTION_CONFLICT", "section cannot be both reviewed and missing")
	var gap: Dictionary = partial.duplicate(true)
	gap["missing_sections"] = ["transport"]
	_code(Gate.assess(gap, _ref()), "A1_HAZARD_SECTION_COVERAGE_INCOMPLETE", "scope coverage rejects unknown/missing declared sections")
	var repeats: Dictionary = partial.duplicate(true)
	repeats["reviewed_sections"].append("classification")
	_code(Gate.assess(repeats, _ref()), "A1_HAZARD_SECTIONS_INVALID", "duplicate reviewed section rejected")


func _test_complete_is_not_universal_safety() -> void:
	var complete: Dictionary = _record()
	complete["completeness"] = "complete_for_declared_scope"
	complete["reviewed_sections"] = ["classification", "labeling", "handling"]
	complete["missing_sections"] = []
	var result: Dictionary = Gate.assess(complete, _ref())
	_ok(result, "complete_for_declared_scope means scoped documentation only")
	_expect(result["safety_assurance"] == false, "scoped complete not equivalent to safe")
	_expect(result["warnings"].has("A1_HAZARD_SCOPE_ONLY_NOT_SAFETY_PROOF"), "scoped completeness warning retained")
	var contradictory: Dictionary = complete.duplicate(true)
	contradictory["missing_sections"] = ["handling"]
	_code(Gate.assess(contradictory, _ref()), "A1_HAZARD_COVERAGE_MISMATCH", "complete requires no missing section")


func _test_absent_requires_evidence() -> void:
	var absent: Dictionary = _record()
	absent["completeness"] = "absent"
	absent["reviewed_sections"] = ["classification", "labeling", "handling"]
	absent["missing_sections"] = []
	absent["statements"] = []
	absent["absence_evidence_field"] = "synthetic-source/record-absence-assessment"
	_ok(Gate.assess(absent, _ref()), "evidenced scoped missing hazard record")
	var missing_evidence: Dictionary = absent.duplicate(true)
	missing_evidence["absence_evidence_field"] = null
	_code(Gate.assess(missing_evidence, _ref()), "A1_HAZARD_ABSENCE_UNEVIDENCED", "absent cannot be inferred from no statements")
	var statements: Dictionary = absent.duplicate(true)
	statements["statements"] = _record()["statements"]
	_code(Gate.assess(statements, _ref()), "A1_HAZARD_ABSENCE_CONTRADICTION", "absent and explicit hazard statement contradict")
	var partial: Dictionary = _record()
	partial["absence_evidence_field"] = "synthetic-no-record"
	_code(Gate.assess(partial, _ref()), "A1_HAZARD_ABSENCE_CONTRADICTION", "partial assessment cannot claim absent source")


func _test_subject_source_and_scope_validation() -> void:
	var other_revision: Dictionary = _record()
	other_revision["substance_ref"]["record_revision"] = 8
	_code(Gate.assess(other_revision, _ref()), "A1_HAZARD_SUBSTANCE_REVISION_MISMATCH", "cannot apply hazard from stale record to new revision")
	var missing_ref: Dictionary = _record()
	missing_ref.erase("substance_ref")
	_code(Gate.assess(missing_ref, _ref()), "A1_HAZARD_SUBSTANCE_UNRESOLVED", "source identity missing")
	var no_source: Dictionary = _record()
	no_source["source"]["record_locator"] = ""
	_code(Gate.assess(no_source, _ref()), "A1_HAZARD_SOURCE_INCOMPLETE", "source locator must be present")
	var no_jurisdiction: Dictionary = _record()
	no_jurisdiction["scope"]["jurisdiction"] = ""
	_code(Gate.assess(no_jurisdiction, _ref()), "A1_HAZARD_SCOPE_INCOMPLETE", "jurisdiction missing")
	var invalid_origin: Dictionary = _record()
	invalid_origin["origin"] = "curated_verified_safe"
	_code(Gate.assess(invalid_origin, _ref()), "A1_HAZARD_ORIGIN_INVALID", "unknown origin cannot be promoted")
	var no_assessment_time: Dictionary = _record()
	no_assessment_time["assessed_at_utc"] = ""
	_code(Gate.assess(no_assessment_time, _ref()), "A1_HAZARD_ASSESSMENT_DATE_MISSING", "assessment date required")


func _test_h_and_p_statement_provenance() -> void:
	var record: Dictionary = _record()
	record["statements"].append({
		"type": "P", "code": "P-TEST",
		"text": "Synthetic precaution placeholder; no real SDS",
		"source_field_locator": "synthetic-document/field-P"
	})
	_ok(Gate.assess(record, _ref()), "separate H and P claims with provenance")
	var duplicate: Dictionary = record.duplicate(true)
	duplicate["statements"].append(record["statements"][0].duplicate(true))
	_code(Gate.assess(duplicate, _ref()), "A1_HAZARD_STATEMENT_DUPLICATE", "duplicate H/P code within one scoped record")
	var missing_provenance: Dictionary = record.duplicate(true)
	missing_provenance["statements"][0]["source_field_locator"] = ""
	_code(Gate.assess(missing_provenance, _ref()), "A1_HAZARD_STATEMENT_INVALID", "H/P field provenance required")
	var incorrect_category: Dictionary = record.duplicate(true)
	incorrect_category["statements"][0]["type"] = "P"
	_code(Gate.assess(incorrect_category, _ref()), "A1_HAZARD_STATEMENT_INVALID", "H code cannot be relabeled P")
	var rights_claim: Dictionary = record.duplicate(true)
	rights_claim["redistribution"] = "approved_for_redistribution"
	_code(Gate.assess(rights_claim, _ref()), "A1_HAZARD_FIELD_UNSUPPORTED", "hazard metadata does not grant offline rights")


func _test_freshness_and_conflicts_are_independent() -> void:
	var record: Dictionary = _record()
	record["freshness"] = "stale"
	record["conflict_status"] = "conflicting"
	var result: Dictionary = Gate.assess(record, _ref())
	_ok(result, "stale and conflicting metadata is still descriptive")
	_expect(result["warnings"].has("A1_HAZARD_STALE"), "stale source warning preserved")
	_expect(result["warnings"].has("A1_HAZARD_CONFLICTING_SOURCES"), "source conflicts warning preserved")
	_expect(result["warnings"].has("A1_HAZARD_PARTIAL_COVERAGE"), "completeness is not overwritten by conflict")
	record["freshness"] = "all_clear"
	_code(Gate.assess(record, _ref()), "A1_HAZARD_FRESHNESS_UNDECLARED", "unsupported freshness label")


func _ok(result: Dictionary, label: String) -> void:
	_expect(result.get("ok", false) == true, label + " expected ok: " + str(result.get("errors", [])))


func _code(result: Dictionary, code: String, label: String) -> void:
	_expect(result.get("ok", true) == false and result.get("errors", []).has(code), label + " expected " + code + ", got " + str(result.get("errors", [])))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
