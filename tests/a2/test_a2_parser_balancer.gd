extends SceneTree

const Parser = preload("res://src/chemistry/a2/chem_equation_parser.gd")
const Balancer = preload("res://src/chemistry/a2/chem_reaction_balancer.gd")
const SpanCodec = preload("res://src/chemistry/a2/chem_source_span.gd")
const Stoichiometry = preload("res://src/chemistry/a2/chem_stoichiometry_handoff.gd")

func _initialize() -> void:
	_test_formula_ast()
	_test_contract_v01_lexer_vectors()
	_test_source_span_utf8_conversion()
	_test_reaction_boundaries()
	_test_nested_and_round_trip()
	_test_single_charge_canonical_round_trip()
	_test_negative_cases()
	_test_exact_conservation_admission_vectors()
	_test_trusted_stoichiometry_handoff()
	_test_balance_validation()
	_test_external_reaction_dto_validation()
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
	assert(empty_group.source_span.start_offset == 2)
	assert(empty_group.source_span.end_offset == 3)

func _test_contract_v01_lexer_vectors() -> void:
	var parser = Parser.new()
	# Local lexical behavior only; the integrator owns approved wire spelling.
	for alias in ["H+", "OH-", "Ag+"]:
		var short_ion: Dictionary = parser.parse_formula(alias)
		assert(short_ion.ok, alias)
		assert(abs(int(short_ion.formula_ast.net_charge)) == 1, alias)
	var positive_caret: Dictionary = parser.parse_formula("H^+")
	assert(positive_caret.ok)
	assert(positive_caret.formula_ast.net_charge == 1)
	var negative_caret: Dictionary = parser.parse_formula("Cl^-")
	assert(negative_caret.ok)
	assert(negative_caret.formula_ast.net_charge == -1)
	var ferric: Dictionary = parser.parse_formula("Fe^3+")
	assert(ferric.ok)
	assert(ferric.formula_ast.net_charge == 3)
	var ambiguous: Dictionary = parser.parse_formula("Fe3+")
	assert(not ambiguous.ok)
	assert(ambiguous.code == "PARSE_AMBIGUOUS_CHARGE")

	var ascii_equilibrium: Dictionary = parser.parse_reaction("H2 + I2 <-> 2HI")
	assert(ascii_equilibrium.ok)
	assert(ascii_equilibrium.reaction.arrow_type == "REVERSIBLE")
	var unicode_equilibrium: Dictionary = parser.parse_reaction("H2 + I2 ⇌ 2HI")
	assert(unicode_equilibrium.ok)
	assert(unicode_equilibrium.reaction.arrow_type == "REVERSIBLE")
	assert(parser.serialize_reaction(ascii_equilibrium.reaction) == "H2 + I2 ⇌ 2HI")

	# A2 local diagnostic spans count Godot String characters, NOT bytes.
	# The integrator v0.1 wire adapter must convert both endpoints over the
	# same unmodified input, including Unicode arrows and Cyrillic text.
	var source := "H2 + O2 → H2Ж"
	var error: Dictionary = parser.parse_reaction(source)
	assert(not error.ok)
	assert(error.code == "PARSE_UNEXPECTED_TOKEN")
	assert(error.source_span.start_offset == 12)
	assert(error.source_span.end_offset == 13)
	assert(source.substr(0, 12).to_utf8_buffer().size() == 14)
	assert(source.substr(0, 13).to_utf8_buffer().size() == 16)

	# An insertion-point error at EOF is a legitimate zero-width span;
	# shared wire SourceSpan consumer policy is still integrator-owned.
	var no_arrow: Dictionary = parser.parse_reaction("H2 + O2")
	assert(not no_arrow.ok)
	assert(no_arrow.code == "PARSE_MISSING_ARROW")
	assert(no_arrow.source_span.start_offset == 7)
	assert(no_arrow.source_span.end_offset == 7)


func _test_source_span_utf8_conversion() -> void:
	# Verify A2's Godot-character offsets and the integrator's UTF-8 byte
	# offsets without changing or normalizing the original source.
	var parser = Parser.new()
	var cyrillic_source := "H2 + O2 → H2Ж"
	var parsed: Dictionary = parser.parse_reaction(cyrillic_source)
	assert(not parsed.ok)
	assert(parsed.code == "PARSE_UNEXPECTED_TOKEN")
	assert(parsed.source_span == {"start_offset": 12, "end_offset": 13})
	var converted: Dictionary = SpanCodec.to_utf8_byte_span(cyrillic_source, parsed.source_span)
	assert(converted.ok)
	assert(converted.source_span == {"utf8_byte_start": 14, "utf8_byte_end": 16})
	var reversed: Dictionary = SpanCodec.to_character_span(cyrillic_source, converted.source_span)
	assert(reversed.ok)
	assert(reversed.source_span == parsed.source_span)

	var unknown_source := "H2 + O2 → H2Xx"
	var unknown: Dictionary = parser.parse_reaction(unknown_source)
	assert(not unknown.ok)
	assert(unknown.code == "PARSE_UNKNOWN_ELEMENT")
	var unknown_bytes: Dictionary = SpanCodec.to_utf8_byte_span(unknown_source, unknown.source_span)
	assert(unknown_bytes.ok)
	assert(unknown_bytes.source_span == {"utf8_byte_start": 14, "utf8_byte_end": 15})

	var missing_arrow_source := "H2 + O2"
	var missing_arrow: Dictionary = parser.parse_reaction(missing_arrow_source)
	assert(not missing_arrow.ok)
	var insertion: Dictionary = SpanCodec.to_utf8_byte_span(missing_arrow_source, missing_arrow.source_span)
	assert(insertion.ok)
	assert(insertion.source_span == {"utf8_byte_start": 7, "utf8_byte_end": 7})
	assert(SpanCodec.to_character_span(missing_arrow_source, insertion.source_span).source_span == missing_arrow.source_span)

	var no_sign_source := "Fe^3"
	var no_sign: Dictionary = parser.parse_formula(no_sign_source)
	assert(not no_sign.ok)
	assert(no_sign.source_span == {"start_offset": 4, "end_offset": 4})
	var no_sign_bytes: Dictionary = SpanCodec.to_utf8_byte_span(no_sign_source, no_sign.source_span)
	assert(no_sign_bytes.ok)
	assert(no_sign_bytes.source_span == {"utf8_byte_start": 4, "utf8_byte_end": 4})

	# A multibyte UTF-8 scalar must not be truncated or mapped into the
	# wrong character. This check is independent of chemical input grammar.
	var emoji_source := "H2😀O"
	var emoji_bytes: Dictionary = SpanCodec.to_utf8_byte_span(emoji_source, {"start_offset": 2, "end_offset": 3})
	assert(emoji_bytes.ok)
	assert(emoji_bytes.source_span == {"utf8_byte_start": 2, "utf8_byte_end": 6})
	assert(SpanCodec.to_character_span(emoji_source, emoji_bytes.source_span).source_span == {"start_offset": 2, "end_offset": 3})
	assert(not SpanCodec.to_character_span(emoji_source, {"utf8_byte_start": 3, "utf8_byte_end": 6}).ok)
	assert(not SpanCodec.to_character_span(emoji_source, {"utf8_byte_start": 2, "utf8_byte_end": 5}).ok)
	assert(not SpanCodec.to_character_span(emoji_source, {"utf8_byte_start": 6, "utf8_byte_end": 2}).ok)
	assert(not SpanCodec.to_character_span(emoji_source, {"utf8_byte_start": 6, "utf8_byte_end": 7}).ok)
	assert(not SpanCodec.to_character_span(emoji_source, {"utf8_byte_start": "2", "utf8_byte_end": 6}).ok)
	assert(not SpanCodec.to_character_span(emoji_source, {"utf8_byte_start": 2, "utf8_byte_end": 6.0}).ok)

	var insertion_after_emoji: Dictionary = SpanCodec.to_utf8_byte_span(emoji_source, {"start_offset": 3, "end_offset": 3})
	assert(insertion_after_emoji.ok)
	assert(insertion_after_emoji.source_span == {"utf8_byte_start": 6, "utf8_byte_end": 6})
	assert(SpanCodec.to_character_span(emoji_source, insertion_after_emoji.source_span).source_span == {"start_offset": 3, "end_offset": 3})

	# Fail closed on missing, reversed, out-of-bounds and non-integer ranges.
	var invalid_spans: Array = [
		{},
		{"start_offset": -1, "end_offset": 0},
		{"start_offset": 2, "end_offset": 1},
		{"start_offset": 0, "end_offset": 5},
		{"start_offset": "2", "end_offset": 3},
		{"start_offset": 2.0, "end_offset": 3}
	]
	for invalid_span in invalid_spans:
		var result: Dictionary = SpanCodec.to_utf8_byte_span(emoji_source, invalid_span)
		assert(not result.ok)
		assert(result.code == "A2_INVALID_SOURCE_SPAN")
	assert(not SpanCodec.to_character_span(emoji_source, {}).ok)

	# Conversion is deterministic and must not change the source text.
	assert(cyrillic_source == "H2 + O2 → H2Ж")
	assert(emoji_source == "H2😀O")


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
	var calcium_solid: Dictionary = parser.parse_formula("Ca(OH)2(s)")
	assert(calcium_solid.ok)
	assert(parser.serialize_formula(calcium_solid.formula_ast, calcium_solid.phase) == "Ca(OH)2(s)")
	var mutated_formula_ast: Dictionary = calcium.formula_ast.duplicate(true)
	mutated_formula_ast.nodes[0].symbol = "O"
	assert(parser.serialize_formula(mutated_formula_ast) == "")

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
	var mutated_reaction: Dictionary = reaction.reaction.duplicate(true)
	mutated_reaction.reactants[0].species.formula_ast.nodes[0].symbol = "O"
	assert(parser.serialize_reaction(mutated_reaction) == "")
	var reparsed: Dictionary = parser.parse_reaction(canonical)
	assert(reparsed.ok)
	assert(reparsed.reaction.reactants[0].species.formula_ast.element_counts["H"] == 2)

func _test_single_charge_canonical_round_trip() -> void:
	var parser = Parser.new()
	# Canonical one-unit charges must not create an ambiguous trailing
	# digit-sign shorthand. Named short aliases remain compatible.
	var cases: Array = [
		{"source": "SO4^-(aq)", "canonical": "SO4^-(aq)", "charge": -1},
		{"source": "H2^+(g)", "canonical": "H2^+(g)", "charge": 1},
		{"source": "Fe2^+", "canonical": "Fe2^+", "charge": 1},
		{"source": "Fe2^-(aq)", "canonical": "Fe2^-(aq)", "charge": -1},
		{"source": "Fe^+", "canonical": "Fe^+", "charge": 1},
		{"source": "Fe^-", "canonical": "Fe^-", "charge": -1},
		{"source": "NH4^+", "canonical": "NH4+", "charge": 1},
		{"source": "OH^-", "canonical": "OH-", "charge": -1},
		{"source": "Ag^+", "canonical": "Ag+", "charge": 1},
		{"source": "SO4^2-", "canonical": "SO4^2-", "charge": -2},
		{"source": "Fe^3+", "canonical": "Fe^3+", "charge": 3}
	]
	for test_case in cases:
		var parsed: Dictionary = parser.parse_formula(test_case.source)
		assert(parsed.ok, test_case.source)
		assert(parsed.formula_ast.net_charge == test_case.charge, test_case.source)
		var original: Dictionary = parsed.formula_ast.duplicate(true)
		var canonical: String = parser.serialize_formula(parsed.formula_ast, parsed.phase)
		assert(canonical == test_case.canonical, test_case.source)
		var round_trip: Dictionary = parser.parse_formula(canonical)
		assert(round_trip.ok, test_case.source)
		assert(round_trip.formula_ast.element_counts == parsed.formula_ast.element_counts, test_case.source)
		assert(round_trip.formula_ast.net_charge == parsed.formula_ast.net_charge, test_case.source)
		assert(round_trip.formula_ast.nodes == parsed.formula_ast.nodes, test_case.source)
		assert(round_trip.phase == parsed.phase, test_case.source)
		assert(parsed.formula_ast == original, test_case.source)

	# The formerly emitted shorthand SO4- must remain rejected, not
	# reinterpreted as a different ion or silently repaired in the lexer.
	var unsafe_short: Dictionary = parser.parse_formula("SO4-")
	assert(not unsafe_short.ok)
	assert(unsafe_short.code == "PARSE_AMBIGUOUS_CHARGE")

	var reaction: Dictionary = parser.parse_reaction("SO4^-(aq) + Na+(aq) -> NaSO4(aq)")
	assert(reaction.ok)
	var original_reaction: Dictionary = reaction.reaction.duplicate(true)
	var reaction_canonical: String = parser.serialize_reaction(reaction.reaction)
	assert(reaction_canonical == "SO4^-(aq) + Na+(aq) -> NaSO4(aq)")
	var reparsed_reaction: Dictionary = parser.parse_reaction(reaction_canonical)
	assert(reparsed_reaction.ok)
	assert(parser.check_balance(reparsed_reaction.reaction).balanced)
	assert(reparsed_reaction.reaction.reactants[0].species.formula_ast.net_charge == -1)
	assert(reaction.reaction == original_reaction)


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
	assert(unclosed.source_span.start_offset == 2)
	assert(unclosed.source_span.end_offset == 3)

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

	var missing_charge_sign: Dictionary = parser.parse_formula("Fe^3")
	assert(not missing_charge_sign.ok)
	assert(missing_charge_sign.code == "PARSE_INVALID_CHARGE")
	assert(missing_charge_sign.source_span.start_offset == 4)
	assert(missing_charge_sign.source_span.end_offset == 4)
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

	var right_separator_source := "H2 -> H2 + + O2"
	var right_separator: Dictionary = parser.parse_reaction(right_separator_source)
	assert(not right_separator.ok)
	assert(right_separator.code == "PARSE_INVALID_SEPARATOR")
	assert(right_separator.source_span.start_offset == right_separator_source.find("+", 10))

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

func _test_exact_conservation_admission_vectors() -> void:
	# Integration admission oracle for the A4 conservation-law handoff.
	# A2 residuals are LEFT minus RIGHT (reactants - products).
	# A4 uses nu = products - reactants, so sum(composition * nu)
	# has the opposite sign for each element/charge. Zero is identical.
	var parser = Parser.new()
	var vectors: Array = [
		{
			"name": "INV-01 balanced H/O",
			"equation": "2H2 + O2 -> 2H2O",
			"balanced": true,
			"elements": {"H": 0, "O": 0},
			"charge": 0
		},
		{
			"name": "INV-02 balanced Ag/Cl and ions",
			"equation": "Ag+(aq) + Cl-(aq) -> AgCl(s)",
			"balanced": true,
			"elements": {"Ag": 0, "Cl": 0},
			"charge": 0
		},
		{
			"name": "INV-03 oxygen deficit on products",
			"equation": "H2 + O2 -> H2O",
			"balanced": false,
			"elements": {"H": 0, "O": 1},
			"charge": 0
		},
		{
			"name": "INV-04 sodium charge nonconservation",
			"equation": "Na+ -> Na",
			"balanced": false,
			"elements": {"Na": 0},
			"charge": 1
		},
		{
			"name": "ionic atom-balanced charge-mismatched",
			"equation": "Fe^3+ + 2Cl- -> FeCl2",
			"balanced": false,
			"elements": {"Fe": 0, "Cl": 0},
			"charge": 1
		},
		{
			"name": "synthetic gas-stoichiometry smoke",
			"equation": "N2O4(g) -> 2NO2(g)",
			"balanced": true,
			"elements": {"N": 0, "O": 0},
			"charge": 0
		},
		{
			"name": "negative hydrogen residual orientation",
			"equation": "H2 + O2 -> 2H2O",
			"balanced": false,
			"elements": {"H": -2, "O": 0},
			"charge": 0
		},
		{
			"name": "duplicate source terms preserve conservation",
			"equation": "H2 + H2 + O2 -> 2H2O",
			"balanced": true,
			"elements": {"H": 0, "O": 0},
			"charge": 0
		}
	]
	for vector in vectors:
		var parsed: Dictionary = parser.parse_reaction(vector.equation)
		assert(parsed.ok, vector.name)
		var original: Dictionary = parsed.reaction.duplicate(true)
		var check: Dictionary = parser.check_balance(parsed.reaction)
		assert(check.ok, vector.name)
		assert(check.balanced == vector.balanced, vector.name)
		assert(check.element_residuals == vector.elements, vector.name)
		assert(check.charge_residual == vector.charge, vector.name)
		# Validation alone does not alter the entered coefficients or DTO.
		assert(parsed.reaction == original, vector.name)

	# Chemistry parser cannot be a validator for A4's abstract A -> B
	# numeric-only benchmark: A is not a chemical element in the lexer.
	var abstract_model: Dictionary = parser.parse_reaction("A -> B")
	assert(not abstract_model.ok)
	assert(abstract_model.code == "PARSE_UNKNOWN_ELEMENT")


func _test_trusted_stoichiometry_handoff() -> void:
	# This A2-local fact builder reparses trusted original text. It never
	# accepts external FormulaAST dictionaries or invents stable species IDs.
	var source := "N2O4(g) -> 2NO2(g)"
	var fact: Dictionary = Stoichiometry.extract_balanced_terms(source)
	assert(fact.ok)
	assert(fact.schema_version == 1)
	assert(fact.original_input == source)
	assert(fact.arrow_type == "FORWARD")
	assert(fact.terms.size() == 2)
	assert(fact.element_residuals == {"N": 0, "O": 0})
	assert(fact.charge_residual == 0)

	var reactant: Dictionary = fact.terms[0]
	var product: Dictionary = fact.terms[1]
	assert(reactant.side == "REACTANT")
	assert(reactant.stoichiometric_coefficient == 1)
	assert(reactant.signed_stoichiometric_coefficient == -1)
	assert(reactant.formula_source_text == "N2O4(g)")
	assert(reactant.element_counts == {"N": 2, "O": 4})
	assert(reactant.net_charge == 0)
	assert(reactant.phase == "GAS")
	assert(product.side == "PRODUCT")
	assert(product.stoichiometric_coefficient == 2)
	assert(product.signed_stoichiometric_coefficient == 2)
	assert(product.formula_source_text == "NO2(g)")
	assert(product.element_counts == {"N": 1, "O": 2})
	assert(product.net_charge == 0)
	assert(product.phase == "GAS")
	assert(reactant.source_term_id != product.source_term_id)
	assert(reactant.source_span.start_offset < reactant.source_span.end_offset)
	assert(product.source_span.start_offset < product.source_span.end_offset)
	assert(not fact.has("species_ref"))
	assert(not reactant.has("species_id"))
	assert(not reactant.has("record_revision"))
	assert(not fact.has("kinetic_order"))
	assert(not fact.has("rate_constant"))

	# The A4 signed stoichiometric products-minus-reactants convention is
	# checked independently of the A2 left-minus-right balance residuals.
	for element in ["N", "O"]:
		var signed_residual := 0
		for term in fact.terms:
			signed_residual += int(term.element_counts.get(element, 0)) * int(term.signed_stoichiometric_coefficient)
		assert(signed_residual == -int(fact.element_residuals[element]))

	# Duplicates are never silently aggregated: source locators remain
	# distinct, while chemical arithmetic still accepts exact balance.
	var duplicates: Dictionary = Stoichiometry.extract_balanced_terms("H2 + H2 + O2 -> 2H2O")
	assert(duplicates.ok)
	assert(duplicates.terms.size() == 4)
	assert(duplicates.terms[0].source_term_id != duplicates.terms[1].source_term_id)
	assert(duplicates.terms[0].formula_source_text == "H2")
	assert(duplicates.terms[1].formula_source_text == "H2")
	assert(duplicates.terms[0].signed_stoichiometric_coefficient == -1)
	assert(duplicates.terms[1].signed_stoichiometric_coefficient == -1)
	assert(duplicates.terms[3].signed_stoichiometric_coefficient == 2)
	assert(duplicates.terms[0].phase == "UNSPECIFIED")

	# Exact charge is separate from atomic conservation and from the
	# model-specific aqueous electroneutrality requirement.
	var ionic: Dictionary = Stoichiometry.extract_balanced_terms("Ag+(aq) + Cl-(aq) -> AgCl(s)")
	assert(ionic.ok)
	assert(ionic.terms.size() == 3)
	assert(ionic.terms[0].net_charge == 1)
	assert(ionic.terms[1].net_charge == -1)
	assert(ionic.terms[2].net_charge == 0)
	assert(ionic.terms[0].phase == "AQUEOUS")
	assert(ionic.terms[2].phase == "SOLID")

	var unbalanced: Dictionary = Stoichiometry.extract_balanced_terms("H2 + O2 -> H2O")
	assert(not unbalanced.ok)
	assert(unbalanced.code == "A2_REACTION_UNBALANCED")
	assert(unbalanced.element_residuals == {"H": 0, "O": 1})
	assert(unbalanced.charge_residual == 0)
	assert(not unbalanced.has("terms"))

	var wrong_charge: Dictionary = Stoichiometry.extract_balanced_terms("Na+ -> Na")
	assert(not wrong_charge.ok)
	assert(wrong_charge.code == "A2_REACTION_UNBALANCED")
	assert(wrong_charge.element_residuals == {"Na": 0})
	assert(wrong_charge.charge_residual == 1)
	assert(not wrong_charge.has("terms"))

	var invalid: Dictionary = Stoichiometry.extract_balanced_terms("Fe3+ -> Fe")
	assert(not invalid.ok)
	assert(invalid.code == "A2_REACTION_PARSE_FAILED")
	assert(invalid.parser_code == "PARSE_AMBIGUOUS_CHARGE")
	assert(not invalid.has("terms"))

	var missing_arrow: Dictionary = Stoichiometry.extract_balanced_terms("H2 + O2")
	assert(not missing_arrow.ok)
	assert(missing_arrow.code == "A2_REACTION_PARSE_FAILED")
	assert(missing_arrow.parser_code == "PARSE_MISSING_ARROW")
	assert(missing_arrow.source_span == {"start_offset": 7, "end_offset": 7})

	# Reversible reactions are represented explicitly; only an A4 consumer
	# may reject that arrow for its current irreversible kinetics model.
	var equilibrium: Dictionary = Stoichiometry.extract_balanced_terms("H2 + I2 <-> 2HI")
	assert(equilibrium.ok)
	assert(equilibrium.arrow_type == "REVERSIBLE")

	# No retained mutable cache: an edited fact cannot poison a new parse.
	fact.terms[0].element_counts["N"] = 999
	var fresh: Dictionary = Stoichiometry.extract_balanced_terms(source)
	assert(fresh.ok)
	assert(fresh.terms[0].element_counts["N"] == 2)


func _test_balance_validation() -> void:
	var parser = Parser.new()
	var unbalanced: Dictionary = parser.parse_reaction("H2 + O2 -> H2O")
	assert(unbalanced.ok)
	var check: Dictionary = parser.check_balance(unbalanced.reaction)
	assert(not check.balanced)
	var malformed_check: Dictionary = parser.check_balance({"schema_version": 1, "arrow_type": "FORWARD", "reactants": [{}], "products": [{}]})
	assert(not malformed_check.ok)
	assert(malformed_check.code == "BALANCE_INVALID_TERM")

	var stale_ast: Dictionary = parser.parse_reaction("H2 + O2 -> H2O")
	assert(stale_ast.ok)
	stale_ast.reaction.reactants[0].species.formula_ast.element_counts["O"] = 1
	var stale_ast_check: Dictionary = parser.check_balance(stale_ast.reaction)
	assert(not stale_ast_check.ok)
	assert(stale_ast_check.code == "BALANCE_INVALID_TERM")

	var stale_nodes: Dictionary = parser.parse_reaction("H2 + O2 -> H2O")
	assert(stale_nodes.ok)
	stale_nodes.reaction.reactants[0].species.formula_ast.nodes[0].symbol = "O"
	var stale_nodes_check: Dictionary = parser.check_balance(stale_nodes.reaction)
	assert(not stale_nodes_check.ok)
	assert(stale_nodes_check.code == "BALANCE_INVALID_TERM")

	var balanced: Dictionary = parser.parse_reaction("2H2 + O2 -> 2H2O")
	assert(balanced.ok)
	assert(parser.check_balance(balanced.reaction).balanced)

	var too_many_terms: Dictionary = {"schema_version": 1, "arrow_type": "FORWARD", "reactants": [], "products": [balanced.reaction.products[0].duplicate(true)]}
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

func _test_external_reaction_dto_validation() -> void:
	var parser = Parser.new()
	var balancer = Balancer.new()
	var parsed: Dictionary = parser.parse_reaction("2H2 + O2 -> 2H2O")
	assert(parsed.ok)
	# A successful parse explicitly materializes coefficient=1 and
	# phase=UNSPECIFIED; externally supplied DTOs may not omit those keys.
	assert(parsed.reaction.schema_version == 1)
	assert(parsed.reaction.arrow_type == "FORWARD")
	assert(parsed.reaction.reactants[1].stoichiometric_coefficient == 1)
	assert(parsed.reaction.reactants[0].species.phase == "UNSPECIFIED")
	assert(parser.check_balance(parsed.reaction).balanced)
	assert(balancer.propose_balance(parsed.reaction).status == "UNIQUE_OPTIMUM")
	assert(parser.serialize_reaction(parsed.reaction) == "2H2 + O2 -> 2H2O")

	var missing_version: Dictionary = parsed.reaction.duplicate(true)
	missing_version.erase("schema_version")
	var unsupported_version: Dictionary = parsed.reaction.duplicate(true)
	unsupported_version.schema_version = 2
	var string_version: Dictionary = parsed.reaction.duplicate(true)
	string_version.schema_version = "1"
	var float_version: Dictionary = parsed.reaction.duplicate(true)
	float_version.schema_version = 1.0
	var missing_arrow: Dictionary = parsed.reaction.duplicate(true)
	missing_arrow.erase("arrow_type")
	var unknown_arrow: Dictionary = parsed.reaction.duplicate(true)
	unknown_arrow.arrow_type = "SIDEWAYS"
	var missing_coefficient: Dictionary = parsed.reaction.duplicate(true)
	missing_coefficient.reactants[1].erase("stoichiometric_coefficient")
	var missing_phase: Dictionary = parsed.reaction.duplicate(true)
	missing_phase.reactants[0].species.erase("phase")
	var invalid_phase: Dictionary = parsed.reaction.duplicate(true)
	invalid_phase.reactants[0].species.phase = "UNKNOWN"

	var cases: Array = [
		{"name": "missing schema version", "dto": missing_version, "balance_code": "BALANCE_INVALID_REACTION"},
		{"name": "unsupported schema version", "dto": unsupported_version, "balance_code": "BALANCE_INVALID_REACTION"},
		{"name": "string schema version", "dto": string_version, "balance_code": "BALANCE_INVALID_REACTION"},
		{"name": "float schema version", "dto": float_version, "balance_code": "BALANCE_INVALID_REACTION"},
		{"name": "missing arrow", "dto": missing_arrow, "balance_code": "BALANCE_INVALID_REACTION"},
		{"name": "unknown arrow", "dto": unknown_arrow, "balance_code": "BALANCE_INVALID_REACTION"},
		{"name": "missing coefficient", "dto": missing_coefficient, "balance_code": "BALANCE_INVALID_TERM"},
		{"name": "missing phase", "dto": missing_phase, "balance_code": "BALANCE_INVALID_TERM"},
		{"name": "invalid phase", "dto": invalid_phase, "balance_code": "BALANCE_INVALID_TERM"}
	]
	for case_entry in cases:
		var dto: Dictionary = case_entry.dto
		var balance: Dictionary = parser.check_balance(dto)
		assert(not balance.ok, String(case_entry.name))
		assert(not balance.balanced, String(case_entry.name))
		assert(balance.code == case_entry.balance_code, String(case_entry.name))
		var proposal: Dictionary = balancer.propose_balance(dto)
		assert(proposal.status == "INVALID_INPUT", String(case_entry.name))
		assert(parser.serialize_reaction(dto) == "", String(case_entry.name))

	# The negative checks do not mutate the original parsed DTO.
	assert(parser.serialize_reaction(parsed.reaction) == "2H2 + O2 -> 2H2O")


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
	assert(context.search_node_count == 3)

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

	var inconsistent_nodes: Dictionary = parsed.reaction.duplicate(true)
	inconsistent_nodes.reactants[0].species.formula_ast.nodes[0].symbol = "O"
	var inconsistent_nodes_result: Dictionary = balancer.propose_balance(inconsistent_nodes)
	assert(inconsistent_nodes_result.status == "INVALID_INPUT")

	var invalid_source_coefficient: Dictionary = parsed.reaction.duplicate(true)
	invalid_source_coefficient.reactants[0].stoichiometric_coefficient = 0
	var invalid_coefficient_result: Dictionary = balancer.propose_balance(invalid_source_coefficient)
	assert(invalid_coefficient_result.status == "INVALID_INPUT")

	var ionic: Dictionary = parser.parse_reaction("Ag+ + Cl- -> AgCl(s)")
	assert(ionic.ok)
	var ionic_serialized := parser.serialize_reaction(ionic.reaction)
	assert(ionic_serialized == "Ag+ + Cl- -> AgCl(s)")
	var ionic_round_trip: Dictionary = parser.parse_reaction(ionic_serialized)
	assert(ionic_round_trip.ok)
	assert(ionic_round_trip.reaction.reactants[0].species.formula_ast.net_charge == 1)
	assert(ionic_round_trip.reaction.products[0].species.phase == "SOLID")
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

	var ambiguous_reaction: Dictionary = parser.parse_reaction("H2(g) + H2(l) -> H2(g) + H4(g)")
	assert(ambiguous_reaction.ok)
	var ambiguous_result: Dictionary = balancer.propose_balance(ambiguous_reaction.reaction)
	assert(ambiguous_result.status == "AMBIGUOUS_OPTIMUM")
	assert(ambiguous_result.optimization.objective_value == 5)
	assert(ambiguous_result.alternative_solutions.size() == 2)

	var duplicate_terms: Dictionary = parser.parse_reaction("H2 + H2 + O2 -> H2O")
	assert(duplicate_terms.ok)
	var duplicate_result: Dictionary = balancer.propose_balance(duplicate_terms.reaction)
	assert(duplicate_result.status == "UNIQUE_OPTIMUM")
	assert(duplicate_result.proposed_coefficients.size() == 3)
	assert(duplicate_result.proposed_coefficients[0].coefficient == 2)
	assert(duplicate_result.proposed_coefficients[0].source_term_ids.size() == 2)
	assert(duplicate_result.proposed_coefficients[1].coefficient == 1)
	assert(duplicate_result.proposed_coefficients[2].coefficient == 2)

	# Proposing coefficients is a pure operation: it must not rewrite parsed source terms.
	assert(duplicate_terms.reaction.reactants[0].stoichiometric_coefficient == 1)
	assert(duplicate_terms.reaction.reactants[1].stoichiometric_coefficient == 1)

	# The balancer proposes a fresh vector; entered coefficients remain source data.
	var entered_coefficients: Dictionary = parser.parse_reaction("7H2 + 3O2 -> 5H2O")
	assert(entered_coefficients.ok)
	assert(not parser.check_balance(entered_coefficients.reaction).balanced)
	var fresh_proposal: Dictionary = balancer.propose_balance(entered_coefficients.reaction)
	assert(fresh_proposal.status == "UNIQUE_OPTIMUM")
	assert(fresh_proposal.proposed_coefficients[0].coefficient == 2)
	assert(fresh_proposal.proposed_coefficients[1].coefficient == 1)
	assert(fresh_proposal.proposed_coefficients[2].coefficient == 2)
	assert(entered_coefficients.reaction.reactants[0].stoichiometric_coefficient == 7)
	assert(entered_coefficients.reaction.reactants[1].stoichiometric_coefficient == 3)
	assert(entered_coefficients.reaction.products[0].stoichiometric_coefficient == 5)

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
	assert(context.search_node_count == 1)
