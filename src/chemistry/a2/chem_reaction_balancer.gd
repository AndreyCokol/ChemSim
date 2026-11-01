extends RefCounted
class_name ChemReactionBalancer

## Exact bounded search for positive integer stoichiometric coefficients.
## A search limit is never reported as proof that no solution exists.
const DEFAULT_MAX_SUM := 64
const DEFAULT_MAX_CANDIDATES := 500000

func propose_balance(reaction: Dictionary, max_sum: int = DEFAULT_MAX_SUM, max_candidates: int = DEFAULT_MAX_CANDIDATES) -> Dictionary:
	var reactants: Array = reaction.get("reactants", [])
	var products: Array = reaction.get("products", [])
	if reactants.is_empty() or products.is_empty():
		return _result("INVALID_INPUT", [], "Reaction must have non-empty sides.")
	if max_sum < reactants.size() + products.size() or max_candidates <= 0:
		return _result("INVALID_INPUT", [], "Search limits are invalid.")

	var terms: Array = []
	var sides: Array = []
	for term in reactants:
		terms.append(term)
		sides.append(1)
	for term in products:
		terms.append(term)
		sides.append(-1)

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
				"objective": "MINIMIZE_SUM_OF_COEFFICIENTS",
				"objective_value": minimum_sum,
				"optimality_proven": true,
				"uniqueness_proven": false
			},
			"alternative_solutions": context.solutions,
			"diagnostics": [{"code": "BALANCE_AMBIGUOUS_OPTIMUM", "severity": "WARNING", "message": "Multiple positive integer solutions share the minimum coefficient sum."}]
		}

	var solution: Array = context.solutions[0]
	var coefficient_records: Array = []
	for i in range(terms.size()):
		coefficient_records.append({
			"term_id": terms[i].get("term_id", "term_%d" % i),
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
			"objective": "MINIMIZE_SUM_OF_COEFFICIENTS",
			"objective_value": minimum_sum,
			"optimality_proven": true,
			"uniqueness_proven": true
		},
		"invariant_checks": invariant,
		"diagnostics": []
	}

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
	var element_sides: Dictionary = {}
	for i in range(terms.size()):
		var ast: Dictionary = terms[i].species.formula_ast
		for element in ast.element_counts:
			if not element_sides.has(element):
				element_sides[element] = {"left": false, "right": false}
			var flags: Dictionary = element_sides[element]
			if int(sides[i]) > 0:
				flags["left"] = true
			else:
				flags["right"] = true
			element_sides[element] = flags
	for element in element_sides:
		var occurrence: Dictionary = element_sides[element]
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
			"objective": "MINIMIZE_SUM_OF_COEFFICIENTS",
			"optimality_proven": false,
			"uniqueness_proven": false
		},
		"diagnostics": [{"code": "BALANCE_" + status, "severity": "ERROR", "message": message}]
	}
