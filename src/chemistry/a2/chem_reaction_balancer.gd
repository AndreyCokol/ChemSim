extends RefCounted
class_name ChemReactionBalancer

## Exact bounded search for positive integer stoichiometric coefficients.
## Identical species on the same side are collapsed into one solver variable.
## A search limit is never reported as proof that no solution exists.
const DEFAULT_MAX_SUM := 64
const DEFAULT_MAX_CANDIDATES := 500000
const MAX_ELEMENT_COUNT := 1000000000
const MAX_ABS_CHARGE := 1000000
const MAX_INPUT_COEFFICIENT := 1000000
const MAX_MAX_SUM := 1000000
const MAX_MAX_CANDIDATES := 2000000
const MAX_SPECIES_TERMS := 128
const FormulaParser = preload("res://src/chemistry/a2/chem_equation_parser.gd")

func propose_balance(reaction: Dictionary, max_sum: int = DEFAULT_MAX_SUM, max_candidates: int = DEFAULT_MAX_CANDIDATES) -> Dictionary:
	var reactants_value: Variant = reaction.get("reactants", [])
	var products_value: Variant = reaction.get("products", [])
	if typeof(reactants_value) != TYPE_ARRAY or typeof(products_value) != TYPE_ARRAY:
		return _result("INVALID_INPUT", [], "Reaction sides must be arrays.")
	var reactants: Array = reactants_value
	var products: Array = products_value
	if reactants.is_empty() or products.is_empty():
		return _result("INVALID_INPUT", [], "Reaction must have non-empty sides.")
	if reactants.size() + products.size() > MAX_SPECIES_TERMS:
		return _result("INVALID_INPUT", [], "Reaction exceeds the maximum supported species-term count.")
	if max_candidates <= 0 or max_candidates > MAX_MAX_CANDIDATES or max_sum <= 0 or max_sum > MAX_MAX_SUM:
		return _result("INVALID_INPUT", [], "Coefficient-sum limit must be between 1 and %d; candidate limit must be between 1 and %d." % [MAX_MAX_SUM, MAX_MAX_CANDIDATES])

	for term in reactants + products:
		if not _is_valid_term(term):
			return _result("INVALID_INPUT", [], "Reaction contains a malformed species term.")
	var terms: Array = []
	var sides: Array = []
	var source_term_ids: Array = []
	_append_aggregated_terms(reactants, 1, terms, sides, source_term_ids)
	_append_aggregated_terms(products, -1, terms, sides, source_term_ids)
	if max_sum < terms.size():
		return _result("INVALID_INPUT", [], "Maximum coefficient sum is smaller than the number of distinct species terms.")

	if _has_structural_impossibility(terms, sides):
		return _result("NO_POSITIVE_SOLUTION", [], "At least one element occurs on only one side of the reaction.")

	var context := {
		"terms": terms,
		"sides": sides,
		"candidate_count": 0,
		"candidate_limit": max_candidates,
		"solutions": [],
		"limit_hit": false
	}
	var minimum_sum := -1
	for total in range(terms.size(), max_sum + 1):
		context.solutions = []
		var current: Array = []
		_enumerate_compositions(0, total, current, context)
		if bool(context.limit_hit):
			return _result("SEARCH_LIMIT_EXCEEDED", [], "Candidate search limit reached before optimality was proven.")
		if not context.solutions.is_empty():
			minimum_sum = total
			break

	if minimum_sum < 0:
		return _result("SEARCH_LIMIT_EXCEEDED", [], "No solution found within the configured coefficient-sum bound; absence of a solution is not proven.")

	if context.solutions.size() > 1:
		return {
			"schema_version": 1,
			"status": "AMBIGUOUS_OPTIMUM",
			"proposed_coefficients": [],
			"method": "BOUNDED_POSITIVE_INTEGER_ENUMERATION",
			"optimization": {
				"objective": "MINIMIZE_SUM_OF_DISTINCT_SPECIES_COEFFICIENTS",
				"objective_value": minimum_sum,
				"optimality_proven": true,
				"uniqueness_proven": false
			},
			"alternative_solutions": context.solutions,
			"solver_terms": _solver_term_metadata(terms, sides, source_term_ids),
			"diagnostics": [{"code": "BALANCE_AMBIGUOUS_OPTIMUM", "severity": "WARNING", "message": "Multiple positive integer solutions share the minimum coefficient sum."}]
		}

	var solution: Array = context.solutions[0]
	var coefficient_records: Array = []
	for i in range(terms.size()):
		coefficient_records.append({
			"term_id": terms[i].get("term_id", "term_%d" % i),
			"source_term_ids": source_term_ids[i],
			"coefficient": int(solution[i])
		})
	var invariant := _verify_solution(terms, sides, solution)
	if not invariant.balanced:
		return _result("INTERNAL_ERROR", [], "Independent atom/charge invariant check failed.")
	return {
		"schema_version": 1,
		"status": "UNIQUE_OPTIMUM",
		"proposed_coefficients": coefficient_records,
		"method": "BOUNDED_POSITIVE_INTEGER_ENUMERATION",
		"optimization": {
			"objective": "MINIMIZE_SUM_OF_DISTINCT_SPECIES_COEFFICIENTS",
			"objective_value": minimum_sum,
			"optimality_proven": true,
			"uniqueness_proven": true
		},
		"solver_terms": _solver_term_metadata(terms, sides, source_term_ids),
		"invariant_checks": invariant,
		"diagnostics": []
	}

func _is_valid_term(term: Variant) -> bool:
	if typeof(term) != TYPE_DICTIONARY:
		return false
	var species: Variant = term.get("species")
	if typeof(species) != TYPE_DICTIONARY:
		return false
	var ast: Variant = species.get("formula_ast")
	if typeof(ast) != TYPE_DICTIONARY or typeof(ast.get("element_counts")) != TYPE_DICTIONARY:
		return false
	if typeof(ast.get("net_charge")) != TYPE_INT or abs(int(ast.net_charge)) > MAX_ABS_CHARGE or ast.element_counts.is_empty():
		return false
	if typeof(ast.get("source_text")) != TYPE_STRING or String(ast.source_text).is_empty():
		return false
	if typeof(species.get("phase", "UNSPECIFIED")) != TYPE_STRING:
		return false
	var phase := String(species.get("phase", "UNSPECIFIED"))
	if not ["UNSPECIFIED", "SOLID", "LIQUID", "GAS", "AQUEOUS"].has(phase):
		return false
	var coefficient: Variant = term.get("stoichiometric_coefficient", 1)
	if typeof(coefficient) != TYPE_INT or int(coefficient) <= 0 or int(coefficient) > MAX_INPUT_COEFFICIENT:
		return false
	# Treat the source formula as the authority: a hand-built or stale DTO must
	# not pair one formula's notation with another formula's elemental makeup.
	var reparsed := FormulaParser.new().parse_formula(String(ast.source_text))
	if not bool(reparsed.get("ok", false)):
		return false
	var parsed_ast: Dictionary = reparsed.formula_ast
	if String(reparsed.phase) != phase:
		return false
	if int(parsed_ast.net_charge) != int(ast.net_charge) or parsed_ast.element_counts != ast.element_counts:
		return false
	for element in ast.element_counts:
		if typeof(element) != TYPE_STRING or typeof(ast.element_counts[element]) != TYPE_INT:
			return false
		if int(ast.element_counts[element]) <= 0 or int(ast.element_counts[element]) > MAX_ELEMENT_COUNT:
			return false
	return true

func _append_aggregated_terms(input_terms: Array, side: int, terms: Array, sides: Array, source_term_ids: Array) -> void:
	var key_to_index: Dictionary = {}
	for term in input_terms:
		var species: Dictionary = term.species
		var ast: Dictionary = species.get("formula_ast", {})
		var key := _species_key(ast, String(species.get("phase", "UNSPECIFIED")))
		var side_key := str(side) + ":" + key
		if key_to_index.has(side_key):
			var existing_index: int = int(key_to_index[side_key])
			source_term_ids[existing_index].append(String(term.get("term_id", "term_%d" % existing_index)))
			continue
		var new_index := terms.size()
		key_to_index[side_key] = new_index
		terms.append(term)
		sides.append(side)
		source_term_ids.append([String(term.get("term_id", "term_%d" % new_index))])

func _species_key(ast: Dictionary, phase: String) -> String:
	# Elemental composition alone is insufficient: isomers can share a formula.
	# Merge only identical source formula notation and phase in this MVP parser.
	return "%s|q:%d|phase:%s" % [String(ast.get("source_text", "")), int(ast.get("net_charge", 0)), phase]

func _solver_term_metadata(terms: Array, sides: Array, source_term_ids: Array) -> Array:
	var metadata: Array = []
	for i in range(terms.size()):
		metadata.append({
			"side": "REACTANT" if int(sides[i]) > 0 else "PRODUCT",
			"source_term_ids": source_term_ids[i],
			"phase": String(terms[i].species.get("phase", "UNSPECIFIED"))
		})
	return metadata

func _enumerate_compositions(position: int, remaining: int, current: Array, context: Dictionary) -> void:
	if bool(context.limit_hit) or context.solutions.size() > 1:
		return
	var term_count: int = context.terms.size()
	if position == term_count - 1:
		if remaining < 1:
			return
		current.append(remaining)
		context.candidate_count = int(context.candidate_count) + 1
		if int(context.candidate_count) > int(context.candidate_limit):
			context.limit_hit = true
			current.pop_back()
			return
		if _is_balanced(context.terms, context.sides, current):
			context.solutions.append(current.duplicate())
		current.pop_back()
		return

	var slots_left := term_count - position - 1
	var max_value := remaining - slots_left
	for value in range(1, max_value + 1):
		current.append(value)
		_enumerate_compositions(position + 1, remaining - value, current, context)
		current.pop_back()
		if bool(context.limit_hit) or context.solutions.size() > 1:
			return

func _is_balanced(terms: Array, sides: Array, coefficients: Array) -> bool:
	var residuals: Dictionary = {}
	var charge_residual := 0
	for i in range(terms.size()):
		var ast: Dictionary = terms[i].species.formula_ast
		var factor := int(sides[i]) * int(coefficients[i])
		for element in ast.element_counts:
			residuals[element] = int(residuals.get(element, 0)) + int(ast.element_counts[element]) * factor
		charge_residual += int(ast.net_charge) * factor
	if charge_residual != 0:
		return false
	for element in residuals:
		if int(residuals[element]) != 0:
			return false
	return true

func _verify_solution(terms: Array, sides: Array, coefficients: Array) -> Dictionary:
	var residuals: Dictionary = {}
	var charge_residual := 0
	for i in range(terms.size()):
		var ast: Dictionary = terms[i].species.formula_ast
		var factor := int(sides[i]) * int(coefficients[i])
		for element in ast.element_counts:
			residuals[element] = int(residuals.get(element, 0)) + int(ast.element_counts[element]) * factor
		charge_residual += int(ast.net_charge) * factor
	var atom_ok := true
	for element in residuals:
		if int(residuals[element]) != 0:
			atom_ok = false
	return {
		"balanced": atom_ok and charge_residual == 0,
		"element_residuals": residuals,
		"charge_residual": charge_residual
	}

func _has_structural_impossibility(terms: Array, sides: Array) -> bool:
	var invariant_sides: Dictionary = {}
	for i in range(terms.size()):
		var ast: Dictionary = terms[i].species.formula_ast
		for element in ast.element_counts:
			if not invariant_sides.has(element):
				invariant_sides[element] = {"left": false, "right": false}
			var flags: Dictionary = invariant_sides[element]
			if int(sides[i]) > 0:
				flags["left"] = true
			else:
				flags["right"] = true
			invariant_sides[element] = flags
	for invariant in invariant_sides:
		var occurrence: Dictionary = invariant_sides[invariant]
		if bool(occurrence["left"]) != bool(occurrence["right"]):
			return true
	return false

func _result(status: String, coefficients: Array, message: String) -> Dictionary:
	return {
		"schema_version": 1,
		"status": status,
		"proposed_coefficients": coefficients,
		"method": "BOUNDED_POSITIVE_INTEGER_ENUMERATION",
		"optimization": {
			"objective": "MINIMIZE_SUM_OF_DISTINCT_SPECIES_COEFFICIENTS",
			"optimality_proven": false,
			"uniqueness_proven": false
		},
		"diagnostics": [{"code": "BALANCE_" + status, "severity": "ERROR", "message": message}]
	}
