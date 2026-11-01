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

	var unclosed: Dictionary = parser.parse_formula("Ca(OH2")
	assert(not unclosed.ok)
	assert(unclosed.code == "PARSE_UNCLOSED_GROUP")

	var zero: Dictionary = parser.parse_formula("H0")
	assert(not zero.ok)
	assert(zero.code == "PARSE_ZERO_COUNT")

	var hydrate: Dictionary = parser.parse_formula("CuSO4·5H2O")
	assert(not hydrate.ok)
	assert(hydrate.code == "PARSE_UNSUPPORTED_SYNTAX")

	var missing_arrow: Dictionary = parser.parse_reaction("H2 + O2")
	assert(not missing_arrow.ok)
	assert(missing_arrow.code == "PARSE_MISSING_ARROW")

func _test_balance_validation() -> void:
	var parser = Parser.new()
	var unbalanced: Dictionary = parser.parse_reaction("H2 + O2 -> H2O")
	assert(unbalanced.ok)
	var check: Dictionary = parser.check_balance(unbalanced.reaction)
	assert(not check.balanced)

	var balanced: Dictionary = parser.parse_reaction("2H2 + O2 -> 2H2O")
	assert(balanced.ok)
	assert(parser.check_balance(balanced.reaction).balanced)

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

	var ionic: Dictionary = parser.parse_reaction("Ag+ + Cl- -> AgCl(s)")
	assert(ionic.ok)
	var ionic_result: Dictionary = balancer.propose_balance(ionic.reaction)
	assert(ionic_result.status == "UNIQUE_OPTIMUM")
	assert(ionic_result.proposed_coefficients[0].coefficient == 1)
	assert(ionic_result.proposed_coefficients[1].coefficient == 1)

	assert(ionic_result.proposed_coefficients[2].coefficient == 1)

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
	assert(duplicate_result.status == "AMBIGUOUS_OPTIMUM")
