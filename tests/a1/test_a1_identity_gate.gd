extends SceneTree

## Synthetic reference tests only; parser output is shaped like A2's API.
## A2 parsing and immutable-reference issuance remain external dependencies.
const Gate = preload("res://src/chemistry/a1/a1_identity_gate.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_complete_identity_and_unresolved_origin()
	_test_ref_revisions_are_exact()
	_test_a2_truth_is_only_charge_and_composition()
	_test_a2_result_shape()
	_test_explicit_phase_boundary()
	if failures.is_empty():
		print("PASS: A1 synthetic identity / A2 reference binding preflight")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _selection() -> Dictionary:
	return {
		"substance_ref": {"id": "synthetic-substance-01", "record_revision": 2},
		"species_ref": {"id": "synthetic-species-01", "record_revision": 4},
		"formula_ast_ref": {"id": "synthetic-ast-01", "record_revision": 3}
	}


func _substance() -> Dictionary:
	return {
		"substance_id": "synthetic-substance-01",
		"record_revision": 2,
		"formula_ast_ref": {"id": "synthetic-ast-01", "record_revision": 3},
		"origin": "curated_reference",
		"display_name": "Synthetic example; not a chemical catalog record"
	}


func _species() -> Dictionary:
	return {
		"species_id": "synthetic-species-01",
		"record_revision": 4,
		"formula_ast_ref": {"id": "synthetic-ast-01", "record_revision": 3},
		"phase": "aq"
	}


func _a2() -> Dictionary:
	return {
		"ok": true,
		"formula_ast": {
			"schema_version": 1,
			"nodes": [{"kind": "synthetic-test-node"}],
			"element_counts": {"H": 2, "O": 1},
			"net_charge": 0,
			"source_text": "H2O(aq)"
		},
		"phase": "AQUEOUS",
		"diagnostics": []
	}


func _model() -> Dictionary:
	return {"required_phase": "aq", "explicit_occurrence_phase_confirmed": false}


func _check(substance: Dictionary, species: Dictionary, parsed: Dictionary,
		selection: Dictionary, model: Dictionary) -> Dictionary:
	return Gate.validate_binding(substance, species, parsed, selection, model)


func _default_check() -> Dictionary:
	return _check(_substance(), _species(), _a2(), _selection(), _model())


func _test_complete_identity_and_unresolved_origin() -> void:
	_expect_ok(_default_check(), "complete binding matches original A2 AST")
	var user_entry := _substance()
	user_entry["origin"] = "user_defined"
	var result := _check(user_entry, _species(), _a2(), _selection(), _model())
	_expect_ok(result, "user origin may preserve its identity")
	_expect(result["origin"] == "user_defined", "user input cannot be promoted to reference")
	user_entry["origin"] = "hypothetical"
	_expect_ok(_check(user_entry, _species(), _a2(), _selection(), _model()), "hypothetical identity is allowed without claiming science")
	user_entry["origin"] = "unlisted_origin"
	_expect_code(_check(user_entry, _species(), _a2(), _selection(), _model()), "A1_ORIGIN_UNDECLARED", "unlisted origin")


func _test_ref_revisions_are_exact() -> void:
	var selection := _selection()
	var selected_substance: Dictionary = selection["substance_ref"]
	selected_substance["record_revision"] = 1
	_expect_code(_check(_substance(), _species(), _a2(), selection, _model()), "A1_SUBSTANCE_REVISION_MISMATCH", "stale substance ref")
	var other_selection := _selection()
	var selected_species: Dictionary = other_selection["species_ref"]
	selected_species["id"] = "other-species"
	_expect_code(_check(_substance(), _species(), _a2(), other_selection, _model()), "A1_SPECIES_REVISION_MISMATCH", "wrong selected species")
	var changed_species := _species()
	var ast_ref: Dictionary = changed_species["formula_ast_ref"]
	ast_ref["record_revision"] = 2
	_expect_code(_check(_substance(), changed_species, _a2(), _selection(), _model()), "A1_FORMULA_AST_REVISION_MISMATCH", "stale species AST")
	var changed_substance := _substance()
	var other_ast_ref: Dictionary = changed_substance["formula_ast_ref"]
	other_ast_ref["id"] = "different-ast"
	_expect_code(_check(changed_substance, _species(), _a2(), _selection(), _model()), "A1_FORMULA_AST_REVISION_MISMATCH", "unbound substance AST")
	var missing_selection := _selection()
	missing_selection.erase("formula_ast_ref")
	_expect_code(_check(_substance(), _species(), _a2(), missing_selection, _model()), "A1_SELECTION_UNRESOLVED", "missing immutable AST selection")
	var invalid_ref := _species()
	invalid_ref["formula_ast_ref"] = {"id": "synthetic-ast-01", "record_revision": 0}
	_expect_code(_check(_substance(), invalid_ref, _a2(), _selection(), _model()), "A1_FORMULA_AST_REF_MISSING", "zero revision is invalid")
	var no_substance_id := _substance()
	no_substance_id.erase("substance_id")
	_expect_code(_check(no_substance_id, _species(), _a2(), _selection(), _model()), "A1_SUBSTANCE_ID_INVALID", "missing catalog ID")
	var no_species_id := _species()
	no_species_id.erase("species_id")
	_expect_code(_check(_substance(), no_species_id, _a2(), _selection(), _model()), "A1_SPECIES_ID_INVALID", "missing occurrence ID")


func _test_a2_truth_is_only_charge_and_composition() -> void:
	for forbidden_field in ["formal_charge", "net_charge", "element_counts", "phase"]:
		var substance := _substance()
		substance[forbidden_field] = 0
		_expect_code(_check(substance, _species(), _a2(), _selection(), _model()), "A1_SUBSTANCE_DUPLICATE_CHEMISTRY_TRUTH", "no independent " + forbidden_field)
	var charged_a2 := _a2()
	var ast: Dictionary = charged_a2["formula_ast"]
	ast["net_charge"] = -1
	_expect_ok(_check(_substance(), _species(), charged_a2, _selection(), _model()), "signed A2 charge is allowed without duplicate persisted field")
	var bad_counts := _a2()
	var ast_bad: Dictionary = bad_counts["formula_ast"]
	ast_bad["element_counts"] = {"H": 0, "O": 1}
	_expect_code(_check(_substance(), _species(), bad_counts, _selection(), _model()), "A1_A2_COMPOSITION_INCOMPLETE", "zero in sparse AST counts is not an atom")
	var missing_counts := _a2()
	var missing_ast: Dictionary = missing_counts["formula_ast"]
	missing_ast["element_counts"] = {}
	_expect_code(_check(_substance(), _species(), missing_counts, _selection(), _model()), "A1_A2_COMPOSITION_INCOMPLETE", "empty composition cannot be chemically resolved")
	var string_count := _a2()
	var count_ast: Dictionary = string_count["formula_ast"]
	count_ast["element_counts"] = {"H": "2", "O": 1}
	_expect_code(_check(_substance(), _species(), string_count, _selection(), _model()), "A1_A2_COMPOSITION_INCOMPLETE", "atom count cannot be string")
	var unknown_charge := _a2()
	var charge_ast: Dictionary = unknown_charge["formula_ast"]
	charge_ast["net_charge"] = "0"
	_expect_code(_check(_substance(), _species(), unknown_charge, _selection(), _model()), "A1_A2_CHARGE_INVALID", "unknown charge cannot be silently zero")


func _test_a2_result_shape() -> void:
	var parser_failure := _a2()
	parser_failure["ok"] = false
	_expect_code(_check(_substance(), _species(), parser_failure, _selection(), _model()), "A1_A2_PARSE_NOT_VALIDATED", "A2 failure must block identity")
	var wrong_schema := _a2()
	var schema_ast: Dictionary = wrong_schema["formula_ast"]
	schema_ast["schema_version"] = 2
	_expect_code(_check(_substance(), _species(), wrong_schema, _selection(), _model()), "A1_A2_AST_SCHEMA_UNSUPPORTED", "unknown AST version")
	var bad_ast := _a2()
	bad_ast.erase("formula_ast")
	_expect_code(_check(_substance(), _species(), bad_ast, _selection(), _model()), "A1_A2_AST_INVALID", "missing AST")
	var not_source_backed := _a2()
	var ast: Dictionary = not_source_backed["formula_ast"]
	ast.erase("source_text")
	_expect_code(_check(_substance(), _species(), not_source_backed, _selection(), _model()), "A1_A2_AST_INVALID", "missing A2 parse provenance")
	var bad_phase := _a2()
	bad_phase["phase"] = "UNKNOWN"
	_expect_code(_check(_substance(), _species(), bad_phase, _selection(), _model()), "A1_A2_PHASE_INVALID", "unknown phase must reject")


func _test_explicit_phase_boundary() -> void:
	var species := _species()
	species["phase"] = "g"
	_expect_code(_check(_substance(), species, _a2(), _selection(), _model()), "A1_PHASE_BINDING_MISMATCH", "A2 aqueous cannot become gas silently")
	_expect_code(_check(_substance(), species, _a2(), _selection(), _model()), "A1_MODEL_PHASE_MISMATCH", "model phase gate")
	species["phase"] = "unspecified"
	_expect_code(_check(_substance(), species, _a2(), _selection(), _model()), "A1_MODEL_PHASE_MISMATCH", "unknown phase cannot satisfy aqueous run")
	var missing_model := _model()
	missing_model.erase("required_phase")
	_expect_code(_check(_substance(), _species(), _a2(), _selection(), missing_model), "A1_MODEL_PHASE_REQUIREMENT_MISSING", "model cannot assume aqueous")
	var a2_unspecified := _a2()
	a2_unspecified["phase"] = "UNSPECIFIED"
	_expect_code(_check(_substance(), _species(), a2_unspecified, _selection(), _model()), "A1_EXPLICIT_PHASE_EVIDENCE_MISSING", "A2 unspecified requires independent explicit-phase evidence")
	var explicitly_selected := _model()
	explicitly_selected["explicit_occurrence_phase_confirmed"] = true
	_expect_ok(_check(_substance(), _species(), a2_unspecified, _selection(), explicitly_selected), "separately confirmed selected aqueous phase")
	var descriptive := _model()
	descriptive["required_phase"] = "unspecified"
	species["phase"] = "unspecified"
	_expect_ok(_check(_substance(), species, a2_unspecified, _selection(), descriptive), "descriptive identity can preserve unknown phase")
	_expect_code(_check(_substance(), species, a2_unspecified, _selection(), _model()), "A1_MODEL_PHASE_MISMATCH", "descriptive phase cannot be used to calculate")


func _expect_ok(result: Dictionary, name: String) -> void:
	_expect(result["ok"] == true, name + " expected ok; got " + str(result["errors"]))


func _expect_code(result: Dictionary, expected_code: String, name: String) -> void:
	_expect(result["ok"] == false and result["errors"].has(expected_code), name + " expected " + expected_code + "; got " + str(result["errors"]))


func _expect(condition: bool, name: String) -> void:
	if not condition:
		failures.append(name)
