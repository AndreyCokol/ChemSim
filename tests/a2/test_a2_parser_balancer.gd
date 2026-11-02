extends SceneTree

const Parser = preload("res://src/chemistry/a2/chem_equation_parser.gd")
const Balancer = preload("res://src/chemistry/a2/chem_reaction_balancer.gd")

func _initialize() -> void:
	_test_formula_ast()
	_test_reaction_boundaries()
	_test_nested_and_round_trip()
	_test_negative_cases()
	_test_balance_validation()
	_test_balance_proposal()
	_test_search_node_guard()
	_test_search_node_budget()
	print("A2 tests: all assertions passed")
	quit(0)

func _test_formula_ast() -> void:
	var parser = Parser.new()
	var sulfate: Dictionary = parser.parse_formula("SO4^2−(aq)")
	assert(sulfate.ok)
	assert(sulfate.formula_ast.net_charge == -2)
	assert(sulfate.phase == "AQUEOUS")
	assert(sulfate.formula_ast.element_counts["S"] == 1)
	assert(sulfate.formula_ast.element_counts["O"] == 4)

	var ammonium: Dictionary = parser.parse_formula("NH4+")
	assert(ammonium.ok)
	assert(ammonium.formula_ast.net_charge == 1)
	assert(ammonium.formula_ast.element_counts["N"] == 1)
	assert(ammonium.formula_ast.element_counts["H"] == 4)

	var ambiguous: Dictionary = parser.parse_formula("Fe3+")
	assert(not ambiguous.ok)
	assert(ambiguous.code == "PARSE_AMBIGUOUS_CHARGE")
	assert(ambiguous.source_span.start_offset == 3)

	var empty_group: Dictionary = parser.parse_formula("Ca()")
	assert(not empty_group.ok)
	assert(empty_group.code == "PARSE_EMPTY_GROUP")

func _test_reaction_boundaries() -> void:
	var parser = Parser.new()
	var parsed: Dictionary = parser.parse_reaction("NH4+ + Cl- -> NH4Cl")
	assert(parsed.ok)
	assert(parsed.reaction.reactants.size() == 2)
	assert(parsed.reaction.products.size() == 1)
	assert(parsed.reaction.reactants[0].species.formula_ast.net_charge == 1)
	assert(parsed.reaction.reactants[1].species.formula_ast.net_charge == -1)

	var reversible: Dictionary = parser.parse_reaction("H2 + I2 <-> 2HI")
	assert(reversible.ok)
	assert(reversible.reaction.arrow_type == "REVERSIBLE")
	assert(reversible.reaction.reactants[0].stoichiometric_coefficient == 1)
	assert(reversible.reaction.products[0].stoichiometric_coefficient == 2)

	var reversible_canonical := parser.serialize_reaction(reversible.reaction)
	assert(reversible_canonical == "H2 + I2 ⇌ 2HI")
	var reversible_round_trip: Dictionary = parser.parse_reaction(reversible_canonical)
	assert(reversible_round_trip.ok)
	assert(reversible_round_trip.reaction.arrow_type == "REVERSIBLE")

	var unicode_forward: Dictionary = parser.parse_reaction("H2 + O2 → H2O")
	assert(unicode_forward.ok)
	assert(parser.serialize_reaction(unicode_forward.reaction) == "H2 + O2 -> H2O")


func _test_nested_and_round_trip() -> void:
	var parser = Parser.new()
	var calcium: Dictionary = parser.parse_formula("Ca(OH)2")
	assert(calcium.ok)
	assert(calcium.formula_ast.element_counts["Ca"] == 1)
	assert(calcium.formula_ast.element_counts["O"] == 2)
	assert(calcium.formula_ast.element_counts["H"] == 2)

	var alum: Dictionary = parser.parse_formula("Al2(SO4)3")
	assert(alum.ok)
	assert(alum.formula_ast.element_counts["Al"] == 2)
	assert(alum.formula_ast.element_counts["S"] == 3)
	assert(alum.formula_ast.element_counts["O"] == 12)

	var ferric: Dictionary = parser.parse_formula("Fe^3+(aq)")
	assert(ferric.ok)
	assert(ferric.formula_ast.net_charge == 3)
	assert(parser.serialize_formula(ferric.formula_ast, ferric.phase) == "Fe^3+(aq)")

	var reaction: Dictionary = parser.parse_reaction("2H2 + O2 -> 2H2O")
	assert(reaction.ok)
	var canonical: String = parser.serialize_reaction(reaction.reaction)
	assert(canonical == "2H2 + O2 -> 2H2O")
	var reparsed: Dictionary = parser.parse_reaction(canonical)
	assert(reparsed.ok)
	assert(reparsed.reaction.reactants[0].species.formula_ast.element_counts["H"] == 2)

func _test_negative_cases() -> void:
	var parser = Parser.new()
	var unknown: Dictionary = parser.parse_formula("Xx2")
	assert(not unknown.ok)
	assert(unknown.code == "PARSE_UNKNOWN_ELEMENT")
	var embedded_unknown: Dictionary = parser.parse_formula("  H2Xx ")
	assert(not embedded_unknown.ok)
	assert(embedded_unknown.code == "PARSE_UNKNOWN_ELEMENT")
	assert(embedded_unknown.source_span.start_offset == 4)

	var unclosed: Dictionary = parser.parse_formula("Ca(OH2")
	assert(not unclosed.ok)
	assert(unclosed.code == "PARSE_UNCLOSED_GROUP")

	var zero: Dictionary = parser.parse_formula("H0")
	assert(not zero.ok)
	assert(zero.code == "PARSE_ZERO_COUNT")

	var oversized_count: Dictionary = parser.parse_formula("H1000001")
	assert(not oversized_count.ok)
	assert(oversized_count.code == "PARSE_COUNT_TOO_LARGE")

	var huge_count_token := "H" + "9".repeat(1000)
	var huge_count: Dictionary = parser.parse_formula(huge_count_token)
	assert(not huge_count.ok)
	assert(huge_count.code == "PARSE_COUNT_TOO_LARGE")

	var oversized_charge: Dictionary = parser.parse_formula("Fe^1000001+")
	assert(not oversized_charge.ok)
	assert(oversized_charge.code == "PARSE_CHARGE_TOO_LARGE")

	var invalid_charge_digits: Dictionary = parser.parse_formula("Fe^x+")
	assert(not invalid_charge_digits.ok)
	assert(invalid_charge_digits.code == "PARSE_INVALID_CHARGE")
	assert(invalid_charge_digits.source_span.start_offset == 3)
	assert(invalid_charge_digits.source_span.end_offset == 4)
	var spaced_invalid_charge: Dictionary = parser.parse_formula("  Fe^x+(aq) ")
	assert(not spaced_invalid_charge.ok)
	assert(spaced_invalid_charge.code == "PARSE_INVALID_CHARGE")
	assert(spaced_invalid_charge.source_span.start_offset == 5)
	assert(spaced_invalid_charge.source_span.end_offset == 6)

	var oversized_coefficient: Dictionary = parser.parse_reaction("1000001H2 -> H2")
	assert(not oversized_coefficient.ok)
	assert(oversized_coefficient.code == "PARSE_COEFFICIENT_TOO_LARGE")

	var fractional_coefficient: Dictionary = parser.parse_reaction("2.5H2 -> H2")
	assert(not fractional_coefficient.ok)
	assert(fractional_coefficient.code == "PARSE_INVALID_COEFFICIENT")
	assert(fractional_coefficient.source_span.start_offset == 1)

	var negative_coefficient: Dictionary = parser.parse_reaction("-H2 -> H2")
	assert(not negative_coefficient.ok)
	assert(negative_coefficient.code == "PARSE_INVALID_COEFFICIENT")
	assert(negative_coefficient.source_span.start_offset == 0)

	var explicit_plus_coefficient: Dictionary = parser.parse_reaction("+H2 -> H2")
	assert(not explicit_plus_coefficient.ok)
	assert(explicit_plus_coefficient.code == "PARSE_INVALID_COEFFICIENT")
	assert(explicit_plus_coefficient.source_span.start_offset == 0)

	var composition_overflow: Dictionary = parser.parse_formula("(H1000000)1000000")
	assert(not composition_overflow.ok)
	assert(composition_overflow.code == "PARSE_COUNT_OVERFLOW")

	var hydrate: Dictionary = parser.parse_formula("CuSO4·5H2O")
	assert(not hydrate.ok)
	assert(hydrate.code == "PARSE_UNSUPPORTED_SYNTAX")

	var missing_arrow: Dictionary = parser.parse_reaction("H2 + O2")
	assert(not missing_arrow.ok)
	assert(missing_arrow.code == "PARSE_MISSING_ARROW")
	assert(missing_arrow.source_span.start_offset == "H2 + O2".length())
	assert(missing_arrow.source_span.end_offset == "H2 + O2".length())

	var multiple_arrow_source := "H2 -> O2 -> H2O"
	var multiple_arrow: Dictionary = parser.parse_reaction(multiple_arrow_source)
	assert(not multiple_arrow.ok)
	assert(multiple_arrow.code == "PARSE_MULTIPLE_ARROWS")
	assert(multiple_arrow.source_span.start_offset == multiple_arrow_source.find("->", 4))
	assert(multiple_arrow.source_span.end_offset == multiple_arrow.source_span.start_offset + 2)

	var empty_separator_source := "H2 + + O2 -> H2O"
	var empty_separator: Dictionary = parser.parse_reaction(empty_separator_source)
	assert(not empty_separator.ok)
	assert(empty_separator.code == "PARSE_INVALID_SEPARATOR")
	assert(empty_separator.source_span.start_offset == empty_separator_source.find("+", 5))
	assert(empty_separator.source_span.end_offset == empty_separator.source_span.start_offset + 1)

	var empty_product_side: Dictionary = parser.parse_reaction("H2 ->   ")
	assert(not empty_product_side.ok)
	assert(empty_product_side.code == "PARSE_EMPTY_SIDE")
	assert(empty_product_side.source_span.start_offset == "H2 ->   ".length())

	# Formula diagnostics in a reaction must use absolute source offsets,
	# including preceding terms, coefficients, and whitespace.
	var bad_product_source := " 2H2 + Xx -> H2"
	var bad_product: Dictionary = parser.parse_reaction(bad_product_source)
	assert(not bad_product.ok)
	assert(bad_product.code == "PARSE_UNKNOWN_ELEMENT")
	assert(bad_product.source_span.start_offset == bad_product_source.find("Xx"))

	var unicode_prefix_source := "H2 + O2 → H2Xx"
	var unicode_prefix_error: Dictionary = parser.parse_reaction(unicode_prefix_source)
	assert(not unicode_prefix_error.ok)
	assert(unicode_prefix_error.code == "PARSE_UNKNOWN_ELEMENT")
	assert(unicode_prefix_error.source_span.start_offset == unicode_prefix_source.find("Xx"))

func _test_balance_validation() -> void:
	var parser = Parser.new()
	var unbalanced: Dictionary = parser.parse_reaction("H2 + O2 -> H2O")
	assert(unbalanced.ok)
	var check: Dictionary = parser.check_balance(unbalanced.reaction)
	assert(not check.balanced)
	var malformed_check: Dictionary = parser.check_balance({"reactants": [{}], "products": [{}]})
	assert(not malformed_check.ok)
	assert(malformed_check.code == "BALANCE_INVALID_TERM")

	var stale_ast: Dictionary = parser.parse_reaction("H2 + O2 -> H2O")
	assert(stale_ast.ok)
	stale_ast.reaction.reactants[0].species.formula_ast.element_counts["O"] = 1
	var stale_ast_check: Dictionary = parser.check_balance(stale_ast.reaction)
	assert(not stale_ast_check.ok)
	assert(stale_ast_check.code == "BALANCE_INVALID_TERM")

	var balanced: Dictionary = parser.parse_reaction("2H2 + O2 -> 2H2O")
	assert(balanced.ok)
	assert(parser.check_balance(balanced.reaction).balanced)

	var too_many_terms: Dictionary = {"reactants": [], "products": [balanced.reaction.products[0].duplicate(true)]}
	for i in range(4096):
		too_many_terms.reactants.append(balanced.reaction.reactants[0].duplicate(true))
	var term_limit_result: Dictionary = parser.check_balance(too_many_terms)
	assert(not term_limit_result.ok)
	assert(term_limit_result.code == "BALANCE_TOO_MANY_TERMS")

	var oversized_balance: Dictionary = parser.parse_reaction("H1000000000 + H1000000000 -> H2")
	assert(oversized_balance.ok)
	var overflow_result: Dictionary = parser.check_balance(oversized_balance.reaction)
	assert(not overflow_result.ok)
	assert(overflow_result.code == "BALANCE_COUNT_OVERFLOW")

func _test_search_node_budget() -> void:
	var balancer = Balancer.new()
	var terms: Array = []
	for i in range(10):
		terms.append({})
	var context := {
		"terms": terms,
		"solutions": [],
		"limit_hit": false,
		"search_node_count": 0,
		"search_node_limit": 3
	}
	balancer._enumerate_compositions(0, 10, [], context)
	assert(context.limit_hit)
	assert(context.search_node_count == 4)

func _test_balance_proposal() -> void:
	var parser = Parser.new()
	var balancer = Balancer.new()
	var parsed: Dictionary = parser.parse_reaction("H2 + O2 -> H2O")
	assert(parsed.ok)
	var result: Dictionary = balancer.propose_balance(parsed.reaction)
	assert(result.status == "UNIQUE_OPTIMUM")
	assert(result.proposed_coefficients.size() == 3)
	assert(result.proposed_coefficients[0].coefficient == 2)
	assert(result.proposed_coefficients[1].coefficient == 1)
	assert(result.proposed_coefficients[2].coefficient == 2)

	var limited: Dictionary = balancer.propose_balance(parsed.reaction, 64, 1)
	assert(limited.status == "SEARCH_LIMIT_EXCEEDED")

	var malformed: Dictionary = balancer.propose_balance({"reactants": [{}], "products": [{}]})
	assert(malformed.status == "INVALID_INPUT")
	var malformed_sides: Dictionary = balancer.propose_balance({"reactants": "not-an-array", "products": []})
	assert(malformed_sides.status == "INVALID_INPUT")

	var oversized_search_bound: Dictionary = balancer.propose_balance(parsed.reaction, 1000001, 500000)
	assert(oversized_search_bound.status == "INVALID_INPUT")
	var oversized_candidate_bound: Dictionary = balancer.propose_balance(parsed.reaction, 64, 2000001)
	assert(oversized_candidate_bound.status == "INVALID_INPUT")

	var inconsistent_ast: Dictionary = parsed.reaction.duplicate(true)
	inconsistent_ast.reactants[0].species.formula_ast.element_counts["O"] = 1
	var inconsistent_result: Dictionary = balancer.propose_balance(inconsistent_ast)
	assert(inconsistent_result.status == "INVALID_INPUT")

	var invalid_source_coefficient: Dictionary = parsed.reaction.duplicate(true)
	invalid_source_coefficient.reactants[0].stoichiometric_coefficient = 0
	var invalid_coefficient_result: Dictionary = balancer.propose_balance(invalid_source_coefficient)
	assert(invalid_coefficient_result.status == "INVALID_INPUT")

	var ionic: Dictionary = parser.parse_reaction("Ag+ + Cl- -> AgCl(s)")
	assert(ionic.ok)
	var ionic_result: Dictionary = balancer.propose_balance(ionic.reaction)
	assert(ionic_result.status == "UNIQUE_OPTIMUM")
	assert(ionic_result.proposed_coefficients[0].coefficient == 1)
	assert(ionic_result.proposed_coefficients[1].coefficient == 1)

	var neutralization: Dictionary = parser.parse_reaction("H+ + OH- -> H2O")
	assert(neutralization.ok)
	var neutralization_result: Dictionary = balancer.propose_balance(neutralization.reaction)
	assert(neutralization_result.status == "UNIQUE_OPTIMUM")
	assert(neutralization_result.proposed_coefficients[0].coefficient == 1)
	assert(neutralization_result.proposed_coefficients[1].coefficient == 1)
	assert(neutralization_result.proposed_coefficients[2].coefficient == 1)

	var calcium: Dictionary = parser.parse_reaction("Ca(OH)2 + HCl -> CaCl2 + H2O")
	assert(calcium.ok)
	var calcium_result: Dictionary = balancer.propose_balance(calcium.reaction)
	assert(calcium_result.status == "UNIQUE_OPTIMUM")
	assert(calcium_result.proposed_coefficients[0].coefficient == 1)
	assert(calcium_result.proposed_coefficients[1].coefficient == 2)
	assert(calcium_result.proposed_coefficients[2].coefficient == 1)
	assert(calcium_result.proposed_coefficients[3].coefficient == 2)

	var impossible: Dictionary = parser.parse_reaction("H2 -> O2")
	assert(impossible.ok)
	var impossible_result: Dictionary = balancer.propose_balance(impossible.reaction)

	assert(impossible_result.status == "NO_POSITIVE_SOLUTION")

	var nitrogen_dioxide: Dictionary = parser.parse_reaction("2NO2(g) ⇌ N2O4(g)")
	assert(nitrogen_dioxide.ok)
	var nitrogen_result: Dictionary = balancer.propose_balance(nitrogen_dioxide.reaction)
	assert(nitrogen_result.status == "UNIQUE_OPTIMUM")
	assert(nitrogen_result.proposed_coefficients[0].coefficient == 2)
	assert(nitrogen_result.proposed_coefficients[1].coefficient == 1)

	var duplicate_terms: Dictionary = parser.parse_reaction("H2 + H2 + O2 -> H2O")
	assert(duplicate_terms.ok)
	var duplicate_result: Dictionary = balancer.propose_balance(duplicate_terms.reaction)
	assert(duplicate_result.status == "UNIQUE_OPTIMUM")
	assert(duplicate_result.proposed_coefficients.size() == 3)
	assert(duplicate_result.proposed_coefficients[0].coefficient == 2)
	assert(duplicate_result.proposed_coefficients[0].source_term_ids.size() == 2)
	assert(duplicate_result.proposed_coefficients[1].coefficient == 1)
	assert(duplicate_result.proposed_coefficients[2].coefficient == 2)

func _test_search_node_guard() -> void:
	var balancer = Balancer.new()
	var context := {
		"limit_hit": false,
		"solutions": [],
		"search_node_count": 0,
		"search_node_limit": 1,
		"terms": [{}, {}, {}]
	}
	balancer._enumerate_compositions(0, 3, [], context)
	assert(context.limit_hit)
	assert(context.search_node_count == 2)
