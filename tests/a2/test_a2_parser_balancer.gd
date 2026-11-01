extends SceneTree

const Parser = preload("res://src/chemistry/a2/chem_equation_parser.gd")
const Balancer = preload("res://src/chemistry/a2/chem_reaction_balancer.gd")

func _initialize() -> void:
	_test_formula_ast()
	_test_reaction_boundaries()
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
