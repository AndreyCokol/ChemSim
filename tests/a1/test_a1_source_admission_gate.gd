extends SceneTree

## Synthetic assertion inputs only. This never approves real chemistry data,
## licenses, Kw values or their related benchmark records.
const Gate = preload("res://src/chemistry/a1/a1_source_admission_gate.gd")
const PropertyGate = preload("res://src/chemistry/a1/a1_property_gate.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_forged_claims_never_grant_admission()
	_test_all_seven_benchmarks_blocked()
	_test_reject_unsupported_benchmark_and_channel()
	_test_metadata_and_rights_decisions_independent()
	_test_provenance_mismatch_and_extra_fields()
	if failures.is_empty():
		print("PASS: A1 independently reviewed source and distribution admission boundary")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _requirement() -> Dictionary:
	return {
		"property_kind": "synthetic_test_constant",
		"unit_id": "1",
		"basis": "synthetic_ideal_concentration_test_only",
		"standard_state": "test-only_standard",
		"phase_context": "aq",
		"medium": "synthetic_water",
		"model_id": "synthetic_model",
		"model_version": "test-v1",
		"temperature_k": 300.0,
		"require_positive": true
	}


func _claim() -> Dictionary:
	return {
		"property_id": "synthetic-property",
		"assertion_revision": 1,
		"property_kind": "synthetic_test_constant",
		"value_state": "present",
		"value": 2.5,
		"unit_id": "1",
		"basis": "synthetic_ideal_concentration_test_only",
		"standard_state": "test-only_standard",
		"phase_context": "aq",
		"medium": "synthetic_water",
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
			"source_id": "claimed-synthetic-source",
			"source_version": "claimed-v1",
			"field_locator": "synthetic/example-only",
			"retrieved_at_utc": "2026-11-03T00:00:00Z"
		},
		"redistribution": {
			"disposition": "approved_for_redistribution",
			"channel": "offline_bundle",
			"field_locator": "synthetic/example-only",
			"evidence_ref": "claimed-unverified-proof",
			"reviewed_by": "caller-provided",
			"reviewed_at_utc": "2026-11-03T00:00:00Z"
		}
	}


func _test_forged_claims_never_grant_admission() -> void:
	var claim: Dictionary = _claim()
	var req: Dictionary = _requirement()
	_ok(PropertyGate.validate_numeric_contract(claim, req), "synthetic numeric metadata can be structurally complete")
	_ok(PropertyGate.validate_distribution_declaration(claim, "offline_bundle"), "synthetic rights declaration can be structurally complete")
	var result: Dictionary = Gate.assess_assertion(claim, req, "AQ-02", "offline_bundle")
	_blocked(result, "self-declared verified/accepted and approved rights are not trusted")
	_expect(result["metadata_preflight_ok"], "numeric preflight reported independently")
	_expect(result["rights_declaration_preflight_ok"], "rights declaration preflight reported independently")
	_code(result, "A1_ADMISSION_SOURCE_NOT_REVIEWED", "source not pinned in A1 registry")
	_code(result, "A1_ADMISSION_RELEASE_NOT_REVIEWED", "license not pinned in A1 registry")
	_expect(result["reference_admitted"] == false and result["redistribution_approved"] == false, "neither claim promoted")
	_expect(result["scientific_data_ready"] == false and result["release_ready"] == false, "no consumer-ready data")


func _test_all_seven_benchmarks_blocked() -> void:
	var all_ids: Array[String] = [
		"AQ-01", "AQ-02", "AQ-03", "AQ-04", "AQ-05", "GAS-01", "GAS-02"
	]
	_expect(Gate.BENCHMARK_IDS == all_ids, "A1 source admission covers exactly the seven A3 fixture keys")
	for benchmark in all_ids:
		var result: Dictionary = Gate.assess_assertion(_claim(), _requirement(), benchmark, "offline_bundle")
		_blocked(result, "admission remains 0/7: " + benchmark)
		_code(result, "A1_ADMISSION_SOURCE_NOT_REVIEWED", "benchmark " + benchmark + " has no independent scientific reviewer")
		_code(result, "A1_ADMISSION_RELEASE_NOT_REVIEWED", "benchmark " + benchmark + " has no source-field rights reviewer")


func _test_reject_unsupported_benchmark_and_channel() -> void:
	var result: Dictionary = Gate.assess_assertion(_claim(), _requirement(), "AQ-08", "offline_bundle")
	_blocked(result, "unknown benchmark may not be auto-added")
	_code(result, "A1_ADMISSION_UNKNOWN_BENCHMARK", "unknown benchmark")
	result = Gate.assess_assertion(_claim(), _requirement(), "AQ-02", "")
	_code(result, "A1_ADMISSION_CHANNEL_MISSING", "distribution channel must be explicit")
	_expect(result["redistribution_approved"] == false, "missing channel can never pass release")


func _test_metadata_and_rights_decisions_independent() -> void:
	var record: Dictionary = _claim()
	record["redistribution"]["disposition"] = "blocked_unknown_license"
	var r: Dictionary = Gate.assess_assertion(record, _requirement(), "AQ-02", "offline_bundle")
	_expect(r["metadata_preflight_ok"], "scientific structure may be complete despite blocked rights")
	_expect(r["rights_declaration_preflight_ok"] == false, "rights claim blocked independently")
	_code(r, "A1_ADMISSION_RIGHTS_DECLARATION_INVALID", "missing release declaration cannot be accepted")
	_code(r, "A1_ADMISSION_SOURCE_NOT_REVIEWED", "model use remains unadmitted despite good metadata")
	record = _claim()
	record["value_state"] = "unknown"
	record.erase("value")
	r = Gate.assess_assertion(record, _requirement(), "AQ-02", "offline_bundle")
	_expect(r["metadata_preflight_ok"] == false, "missing scientific value blocks model")
	_expect(r["rights_declaration_preflight_ok"], "separate release declaration may still be syntactically valid")
	_code(r, "A1_ADMISSION_PROPERTY_METADATA_INVALID", "numeric source content must be present")
	_blocked(r, "rights declaration cannot substitute for missing scientific data")
	record = _claim()
	record["model_eligibility"]["status"] = "accepted"
	record["source"]["field_locator"] = "different-field"
	r = Gate.assess_assertion(record, _requirement(), "AQ-02", "offline_bundle")
	_expect(r["metadata_preflight_ok"], "metadata source locator still nonempty")
	_code(r, "A1_ADMISSION_RIGHTS_DECLARATION_INVALID", "rights must match exact field")


func _test_provenance_mismatch_and_extra_fields() -> void:
	var record: Dictionary = _claim()
	record["origin"] = "hypothetical"
	var result: Dictionary = Gate.assess_assertion(record, _requirement(), "AQ-02", "offline_bundle")
	_code(result, "A1_ADMISSION_PROPERTY_METADATA_INVALID", "hypothetical data is not curated reference")
	_blocked(result, "hypothetical cannot be promoted by claimed rights")
	record = _claim()
	record["source"]["source_version"] = ""
	result = Gate.assess_assertion(record, _requirement(), "AQ-02", "offline_bundle")
	_code(result, "A1_ADMISSION_PROPERTY_METADATA_INVALID", "source edition/version missing")
	record = _claim()
	record["local_review_registry"] = {"status": "admitted"}
	result = Gate.assess_assertion(record, _requirement(), "AQ-02", "offline_bundle")
	_blocked(result, "caller cannot inject local reviewer manifest through extra fields")
	record = _claim()
	record["value"] = NAN
	result = Gate.assess_assertion(record, _requirement(), "AQ-02", "offline_bundle")
	_code(result, "A1_ADMISSION_PROPERTY_METADATA_INVALID", "NaN scientific value not admitted")


func _blocked(result: Dictionary, label: String) -> void:
	_expect(result.get("ok", true) == false, label + ": top-level admission must fail")
	_expect(result.get("release_ready", true) == false, label + ": release cannot pass")


func _ok(result: Dictionary, label: String) -> void:
	_expect(result.get("ok", false) == true, label + ", got " + str(result.get("errors", [])))


func _code(result: Dictionary, code: String, label: String) -> void:
	_expect(result.get("errors", []).has(code), label + " missing " + code + ", got " + str(result.get("errors", [])))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
