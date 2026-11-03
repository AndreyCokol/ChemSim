extends SceneTree

## A1-only contract tests using SYNTHETIC metadata; never a chemistry fixture.
const Gate = preload("res://src/chemistry/a1/a1_property_gate.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_present_value_and_missing_states()
	_test_numeric_type_and_positivity()
	_test_exact_scope_and_temperature()
	_test_uncertainty_and_evidence()
	_test_source_and_model_revision()
	_test_distribution_is_independent()
	if failures.is_empty():
		print("PASS: A1 synthetic property contract preflight")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _required() -> Dictionary:
	return {
		"property_kind": "synthetic_scalar",
		"unit_id": "1",
		"basis": "synthetic_test_basis",
		"standard_state": "synthetic_standard_state",
		"phase_context": "aq",
		"medium": "test_water",
		"temperature_k": 300.0,
		"model_id": "synthetic_model",
		"model_version": "test-v1",
		"require_positive": true
	}


func _record() -> Dictionary:
	return {
		"property_id": "test-only-record",
		"assertion_revision": 1,
		"property_kind": "synthetic_scalar",
		"value_state": "present",
		"value": 2.5,
		"unit_id": "1",
		"basis": "synthetic_test_basis",
		"standard_state": "synthetic_standard_state",
		"phase_context": "aq",
		"medium": "test_water",
		"temperature_k": 300.0,
		"uncertainty_status": "not_reported",
		"origin": "curated_reference",
		"quality": "verified",
		"review": "accepted",
		"model_eligibility": {
			"model_id": "synthetic_model",
			"model_version": "test-v1",
			"status": "accepted"
		},
		"source": {
			"source_id": "synthetic-test-source",
			"source_version": "test-v1",
			"field_locator": "test-only/fixture-1",
			"retrieved_at_utc": "2026-11-03T00:00:00Z"
		},
		"redistribution": {
			"disposition": "blocked_unknown_license",
			"channel": "offline_bundle",
			"field_locator": "test-only/fixture-1"
		}
	}


func _test_present_value_and_missing_states() -> void:
	var original := _record()
	_expect_ok(Gate.validate_numeric_contract(original, _required()), "complete metadata")
	for state in ["unknown", "not_reported", "not_applicable"]:
		var changed := _record()
		changed["value_state"] = state
		changed.erase("value")
		_expect_code(Gate.validate_numeric_contract(changed, _required()), "A1_VALUE_UNAVAILABLE", "value-state " + state)
	var bad_revision := _record()
	bad_revision["assertion_revision"] = 0
	_expect_code(Gate.validate_numeric_contract(bad_revision, _required()), "A1_IDENTITY_INCOMPLETE", "nonpositive revision")
	_expect(not original.has("license_identifier"), "source metadata does not imply release permission")


func _test_numeric_type_and_positivity() -> void:
	for value in [true, "2.5", null, INF, NAN]:
		var changed := _record()
		changed["value"] = value
		_expect_code(Gate.validate_numeric_contract(changed, _required()), "A1_VALUE_NOT_FINITE_NUMBER", "invalid numeric input")
	var zero := _record()
	zero["value"] = 0.0
	_expect_code(Gate.validate_numeric_contract(zero, _required()), "A1_VALUE_NOT_POSITIVE", "positive-only synthetic constant")
	var nonnegative := _required()
	nonnegative["require_positive"] = false
	_expect_ok(Gate.validate_numeric_contract(zero, nonnegative), "explicit present zero when positivity is not required")


func _test_exact_scope_and_temperature() -> void:
	for field in ["property_kind", "unit_id", "basis", "standard_state", "phase_context", "medium"]:
		var changed := _record()
		changed[field] = "other"
		_expect_code(Gate.validate_numeric_contract(changed, _required()), "A1_CONTEXT_MISMATCH", "scope " + field)
	var unregistered := _record()
	var matching_unregistered := _required()
	unregistered["unit_id"] = "synthetic/unregistered"
	matching_unregistered["unit_id"] = "synthetic/unregistered"
	_expect_code(Gate.validate_numeric_contract(unregistered, matching_unregistered), "A1_UNIT_UNREGISTERED", "unknown units cannot be whitelisted by matching labels")
	var no_temperature := _record()
	no_temperature.erase("temperature_k")
	_expect_code(Gate.validate_numeric_contract(no_temperature, _required()), "A1_TEMPERATURE_MISSING", "missing temperature")
	var wrong_temperature := _record()
	wrong_temperature["temperature_k"] = 301.0
	_expect_code(Gate.validate_numeric_contract(wrong_temperature, _required()), "A1_TEMPERATURE_MISMATCH", "no temperature extrapolation")
	var missing_positive_policy := _required()
	missing_positive_policy.erase("require_positive")
	_expect_code(Gate.validate_numeric_contract(_record(), missing_positive_policy), "A1_REQUIREMENT_INCOMPLETE", "no implicit positivity policy")
	var pressure_requirement := _required()
	pressure_requirement["pressure_pa"] = 101325.0
	_expect_code(Gate.validate_numeric_contract(_record(), pressure_requirement), "A1_PRESSURE_MISSING", "missing required P")
	var pressure_record := _record()
	pressure_record["pressure_pa"] = 101325.0
	_expect_ok(Gate.validate_numeric_contract(pressure_record, pressure_requirement), "exact scoped pressure")
	pressure_record["pressure_pa"] = 100000.0
	_expect_code(Gate.validate_numeric_contract(pressure_record, pressure_requirement), "A1_PRESSURE_MISMATCH", "no silent pressure conversion")
	var no_request_temperature := _required()
	no_request_temperature.erase("temperature_k")
	_expect_code(Gate.validate_numeric_contract(_record(), no_request_temperature), "A1_REQUIREMENT_INCOMPLETE", "no implicit request T")


func _test_uncertainty_and_evidence() -> void:
	var absent := _record()
	absent.erase("uncertainty_status")
	_expect_code(Gate.validate_numeric_contract(absent, _required()), "A1_UNCERTAINTY_UNDECLARED", "no default zero uncertainty")
	var contradiction := _record()
	contradiction["uncertainty"] = 0.0
	_expect_code(Gate.validate_numeric_contract(contradiction, _required()), "A1_UNCERTAINTY_CONTRADICTION", "not-reported with numeric value")
	var reported := _record()
	reported["uncertainty_status"] = "reported"
	reported["uncertainty"] = 0.3
	_expect_ok(Gate.validate_numeric_contract(reported, _required()), "explicit nonnegative uncertainty")
	reported["uncertainty"] = -0.3
	_expect_code(Gate.validate_numeric_contract(reported, _required()), "A1_UNCERTAINTY_INVALID", "negative uncertainty")
	for field in ["origin", "quality", "review"]:
		var bad := _record()
		bad[field] = "hypothetical"
		_expect(not Gate.validate_numeric_contract(bad, _required())["ok"], "unreviewed or hypothetical reference " + field)


func _test_source_and_model_revision() -> void:
	for key in ["source_id", "source_version", "field_locator", "retrieved_at_utc"]:
		var missing := _record()
		var source: Dictionary = missing["source"]
		source.erase(key)
		_expect_code(Gate.validate_numeric_contract(missing, _required()), "A1_PROVENANCE_INCOMPLETE", "source " + key)
	var wrong_version := _record()
	var eligibility: Dictionary = wrong_version["model_eligibility"]
	eligibility["model_version"] = "test-v2"
	_expect_code(Gate.validate_numeric_contract(wrong_version, _required()), "A1_MODEL_ELIGIBILITY_MISMATCH", "model revision")
	var no_review := _record()
	no_review["review"] = "unreviewed"
	_expect_code(Gate.validate_numeric_contract(no_review, _required()), "A1_EVIDENCE_NOT_ACCEPTED", "unreviewed reference")


func _test_distribution_is_independent() -> void:
	var record := _record()
	_expect_ok(Gate.validate_numeric_contract(record, _required()), "scientific metadata structurally complete")
	_expect_code(Gate.validate_distribution_declaration(record, "offline_bundle"), "A1_RIGHTS_NOT_APPROVED", "unknown license")
	for disposition in ["local_review_only", "blocked_restricted", "blocked_unknown_license"]:
		var limited := _record()
		var rights: Dictionary = limited["redistribution"]
		rights["disposition"] = disposition
		_expect_code(Gate.validate_distribution_declaration(limited, "offline_bundle"), "A1_RIGHTS_NOT_APPROVED", "disposition " + disposition)
	var synthetic_approved := _record()
	var rights: Dictionary = synthetic_approved["redistribution"]
	rights["disposition"] = "approved_for_redistribution"
	rights["evidence_ref"] = "synthetic-test-proof-only"
	rights["reviewed_by"] = "synthetic-test-reviewer"
	rights["reviewed_at_utc"] = "2026-11-03T00:00:00Z"
	_expect_ok(Gate.validate_distribution_declaration(synthetic_approved, "offline_bundle"), "synthetic rights declaration")
	_expect_code(Gate.validate_distribution_declaration(synthetic_approved, "commercial_bundle"), "A1_RIGHTS_CHANNEL_MISMATCH", "right channel isolation")
	rights["field_locator"] = "different-source-field"
	_expect_code(Gate.validate_distribution_declaration(synthetic_approved, "offline_bundle"), "A1_RIGHTS_FIELD_MISMATCH", "field isolation")
	rights["field_locator"] = "test-only/fixture-1"
	rights.erase("evidence_ref")
	_expect_code(Gate.validate_distribution_declaration(synthetic_approved, "offline_bundle"), "A1_RIGHTS_EVIDENCE_INCOMPLETE", "missing rights evidence")
	var no_model := synthetic_approved.duplicate(true)
	no_model.erase("model_eligibility")
	_expect(not Gate.validate_numeric_contract(no_model, _required())["ok"], "rights declaration cannot confer scientific/model acceptance")


func _expect_ok(result: Dictionary, name: String) -> void:
	_expect(result["ok"] == true, name + " -> " + str(result["errors"]))


func _expect_code(result: Dictionary, expected_code: String, name: String) -> void:
	_expect(result["ok"] == false and result["errors"].has(expected_code), name + " should report " + expected_code + " got " + str(result["errors"]))


func _expect(condition: bool, name: String) -> void:
	if not condition:
		failures.append(name)
