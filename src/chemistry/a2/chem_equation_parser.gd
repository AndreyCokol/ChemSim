extends RefCounted
class_name ChemEquationParser

## Pure-domain parser for the ChemSim MVP. It does not balance or mutate input.
const ELEMENTS := [
	"H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne",
	"Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca",
	"Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn",
	"Ga", "Ge", "As", "Se", "Br", "Kr", "Rb", "Sr", "Y", "Zr",
	"Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn",
	"Sb", "Te", "I", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd",
	"Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
	"Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg",
	"Tl", "Pb", "Bi", "Po", "At", "Rn", "Fr", "Ra", "Ac", "Th",
	"Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm",
	"Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds",
	"Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og"
]
const PHASES := {"(s)": "SOLID", "(l)": "LIQUID", "(g)": "GAS", "(aq)": "AQUEOUS"}
const MAX_FORMULA_LENGTH := 4096
const MAX_REACTION_LENGTH := 16384
const MAX_BALANCE_TERMS := 4096
const MAX_GROUP_DEPTH := 64
const MAX_INTEGER_TOKEN := 1000000
const MAX_COMPOSITION_COUNT := 1000000000
const MAX_BALANCE_TOTAL := 1000000000000000000
const ARROWS := {"->": "FORWARD", "→": "FORWARD", "⇌": "REVERSIBLE", "<->": "REVERSIBLE"}
# Explicit aliases preserve common MVP spellings while rejecting ambiguous Fe3+ / Co3+.
const SIMPLE_ION_ALIASES := [
	"H+", "OH-", "NH4+", "Ag+", "Cl-", "Na+", "K+",
	"Li+", "NO3-", "NO2-", "HCO3-", "CH3COO-"
]

func parse_formula(source: String) -> Dictionary:
	var original := source
	if source.length() > MAX_FORMULA_LENGTH:
		return _failure("PARSE_FORMULA_TOO_LONG", "Formula exceeds the configured length limit.", 0, source.length())
	var text := source.strip_edges()
	if text.is_empty():
		return _failure("PARSE_EMPTY_FORMULA", "Formula is empty.", 0, original.length())

	var trimmed_start := original.find(original.strip_edges())
	var phase := "UNSPECIFIED"
	for suffix in PHASES:
		if text.ends_with(suffix):
			phase = PHASES[suffix]
			text = text.substr(0, text.length() - suffix.length())
			break

	var charge := 0
	var charge_result := _extract_charge(text)
	if not charge_result.ok:
		var fallback_charge_error_start := text.rfind("^")
		if fallback_charge_error_start < 0:
			fallback_charge_error_start = maxi(0, text.length() - 1)
		var charge_error_start := int(charge_result.get("error_offset", fallback_charge_error_start))
		var absolute_charge_start := maxi(0, trimmed_start) + charge_error_start
		var absolute_charge_end := mini(original.length(), absolute_charge_start + (1 if absolute_charge_start < original.length() else 0))
		return _failure(charge_result.code, charge_result.message, absolute_charge_start, absolute_charge_end)
	charge = charge_result.charge
	text = charge_result.body

	if text.is_empty():
		var empty_body_start := maxi(0, trimmed_start)
		return _failure("PARSE_EMPTY_FORMULA", "Formula body is empty.", empty_body_start, original.length())

	var state := {"index": 0, "error": "", "error_index": 0, "depth": 0}
	var nodes := _parse_sequence(text, state, false)
	if not String(state.error).is_empty():
		var error_start := maxi(0, trimmed_start) + int(state.error_index)
		var error_end := mini(original.length(), error_start + (1 if error_start < original.length() else 0))
		return _failure(String(state.error), _message_for(String(state.error)), error_start, error_end)
	if int(state.index) != text.length():
		var unexpected_error_start := maxi(0, trimmed_start) + int(state.index)
		return _failure("PARSE_UNEXPECTED_TOKEN", "Unexpected token in formula.", unexpected_error_start, mini(original.length(), unexpected_error_start + 1))

	var expansion_state := {"overflow": false}
	var composition := _expand_nodes(nodes, expansion_state)
	if bool(expansion_state.overflow):
		return _failure("PARSE_COUNT_OVERFLOW", "Expanded element count exceeds the configured safe limit.", 0, original.length())
	return {
		"ok": true,
		"formula_ast": {
			"schema_version": 1,
			"nodes": nodes,
			"net_charge": charge,
			"element_counts": composition,
			"source_text": original
		},
		"phase": phase,
		"diagnostics": []
	}

func parse_reaction(source: String) -> Dictionary:
	if source.length() > MAX_REACTION_LENGTH:
		return _failure("PARSE_REACTION_TOO_LONG", "Reaction exceeds the configured length limit.", 0, source.length())
	var arrow_match := _find_arrow(source)
	if not arrow_match.ok:
		var arrow_error_start := int(arrow_match.get("position", source.length()))
		var arrow_error_end := int(arrow_match.get("end_position", arrow_error_start))
		return _failure(arrow_match.code, arrow_match.message, arrow_error_start, arrow_error_end)

	var arrow_text: String = arrow_match.arrow
	var arrow_pos: int = arrow_match.position
	var left_text := source.substr(0, arrow_pos)
	var right_text := source.substr(arrow_pos + arrow_text.length())
	var left_terms := _split_side(left_text)
	var right_terms := _split_side(right_text)
	if not left_terms.ok:
		var left_error_start := int(left_terms.get("position", 0))
		var left_error_end := int(left_terms.get("end_position", left_error_start))
		return _failure(left_terms.code, left_terms.message, left_error_start, left_error_end)
	if not right_terms.ok:
		var right_error_start := arrow_pos + arrow_text.length() + int(right_terms.get("position", 0))
		var right_error_end := arrow_pos + arrow_text.length() + int(right_terms.get("end_position", right_terms.get("position", 0)))
		return _failure(right_terms.code, right_terms.message, right_error_start, right_error_end)
	if left_terms.parts.is_empty() or right_terms.parts.is_empty():
		return _failure("PARSE_EMPTY_SIDE", "Both reaction sides must contain at least one term.", 0, source.length())

	var reactants: Array = []
	var products: Array = []
	var diagnostics: Array = []
	for part in left_terms.parts:
		var term_result := _parse_term(String(part.text), int(part.start))
		if not term_result.ok:
			return term_result
		reactants.append(term_result.term)
	for part in right_terms.parts:
		var term_result := _parse_term(String(part.text), arrow_pos + arrow_text.length() + int(part.start))
		if not term_result.ok:
			return term_result
		products.append(term_result.term)

	return {
		"ok": true,
		"reaction": {
			"schema_version": 1,
			"reactants": reactants,
			"products": products,
			"arrow_type": ARROWS[arrow_text],
			"source_text": source,
			"balance_status": "NOT_CHECKED"
		},
		"diagnostics": diagnostics
	}

func check_balance(reaction: Dictionary) -> Dictionary:
	if typeof(reaction.get("reactants")) != TYPE_ARRAY or typeof(reaction.get("products")) != TYPE_ARRAY:
		return {"ok": false, "balanced": false, "code": "BALANCE_INVALID_REACTION"}
	if reaction.reactants.is_empty() or reaction.products.is_empty():
		return {"ok": false, "balanced": false, "code": "BALANCE_EMPTY_SIDE"}
	if reaction.reactants.size() + reaction.products.size() > MAX_BALANCE_TERMS:
		return {"ok": false, "balanced": false, "code": "BALANCE_TOO_MANY_TERMS"}
	for term in reaction.reactants + reaction.products:
		if not _is_valid_reaction_term(term):
			return {"ok": false, "balanced": false, "code": "BALANCE_INVALID_TERM"}
	var left: Dictionary = {}
	var right: Dictionary = {}
	var left_charge := 0
	var right_charge := 0
	for term in reaction.get("reactants", []):
		var ast: Dictionary = term.species.formula_ast
		var coefficient := int(term.stoichiometric_coefficient)
		for element in ast.element_counts:
			var addition := int(ast.element_counts[element]) * coefficient
			if addition > MAX_BALANCE_TOTAL or int(left.get(element, 0)) > MAX_BALANCE_TOTAL - addition:
				return {"ok": false, "balanced": false, "code": "BALANCE_COUNT_OVERFLOW"}
			left[element] = int(left.get(element, 0)) + addition
		var charge_addition := int(ast.net_charge) * coefficient
		if abs(charge_addition) > MAX_BALANCE_TOTAL or abs(left_charge) > MAX_BALANCE_TOTAL - abs(charge_addition):
			return {"ok": false, "balanced": false, "code": "BALANCE_CHARGE_OVERFLOW"}
		left_charge += charge_addition
	for term in reaction.get("products", []):
		var ast: Dictionary = term.species.formula_ast
		var coefficient := int(term.stoichiometric_coefficient)
		for element in ast.element_counts:
			var addition := int(ast.element_counts[element]) * coefficient
			if addition > MAX_BALANCE_TOTAL or int(right.get(element, 0)) > MAX_BALANCE_TOTAL - addition:
				return {"ok": false, "balanced": false, "code": "BALANCE_COUNT_OVERFLOW"}
			right[element] = int(right.get(element, 0)) + addition
		var charge_addition := int(ast.net_charge) * coefficient
		if abs(charge_addition) > MAX_BALANCE_TOTAL or abs(right_charge) > MAX_BALANCE_TOTAL - abs(charge_addition):
			return {"ok": false, "balanced": false, "code": "BALANCE_CHARGE_OVERFLOW"}
		right_charge += charge_addition

	var elements: Dictionary = {}
	for element in left:
		elements[element] = true
	for element in right:
		elements[element] = true
	var residuals: Dictionary = {}
	var balanced := true
	for element in elements:
		var residual := int(left.get(element, 0)) - int(right.get(element, 0))
		residuals[element] = residual
		if residual != 0:
			balanced = false
	var charge_residual := left_charge - right_charge
	if charge_residual != 0:
		balanced = false
	return {
		"ok": true,
		"balanced": balanced,
		"element_residuals": residuals,
		"charge_residual": charge_residual
	}


func serialize_formula(formula_ast: Dictionary, phase: String = "UNSPECIFIED") -> String:
	var output := _serialize_nodes(formula_ast.get("nodes", []))
	var charge := int(formula_ast.get("net_charge", 0))
	if charge == 1:
		output += "+"
	elif charge == -1:
		output += "-"
	elif charge > 1:
		output += "^%d+" % charge
	elif charge < -1:
		output += "^%d-" % abs(charge)
	var phase_suffix := {
		"SOLID": "(s)",
		"LIQUID": "(l)",
		"GAS": "(g)",
		"AQUEOUS": "(aq)"
	}
	output += String(phase_suffix.get(phase, ""))
	return output

func serialize_reaction(reaction: Dictionary) -> String:
	var left := PackedStringArray()
	var right := PackedStringArray()
	for term in reaction.get("reactants", []):
		var coefficient := int(term.get("stoichiometric_coefficient", 1))
		var ast: Dictionary = term.species.formula_ast
		var formula := serialize_formula(ast, String(term.species.get("phase", "UNSPECIFIED")))
		left.append(("" if coefficient == 1 else str(coefficient)) + formula)
	for term in reaction.get("products", []):
		var coefficient := int(term.get("stoichiometric_coefficient", 1))
		var ast: Dictionary = term.species.formula_ast
		var formula := serialize_formula(ast, String(term.species.get("phase", "UNSPECIFIED")))
		right.append(("" if coefficient == 1 else str(coefficient)) + formula)
	var arrow := " ⇌ " if reaction.get("arrow_type", "FORWARD") == "REVERSIBLE" else " -> "
	return " + ".join(left) + arrow + " + ".join(right)

func _serialize_nodes(nodes: Array) -> String:
	var output := ""
	for node in nodes:
		if node.type == "element":
			var count := int(node.count)
			output += String(node.symbol) + ("" if count == 1 else str(count))
		else:
			var nested := _serialize_nodes(node.children)
			var multiplier := int(node.multiplier)
			output += "(" + nested + ")" + ("" if multiplier == 1 else str(multiplier))
	return output

func _parse_term(raw_text: String, global_start: int) -> Dictionary:
	var text := raw_text.strip_edges()
	var leading := raw_text.find(text)
	var formula_offset := global_start + leading
	if text.begins_with("-") or text.begins_with("+") or text.begins_with("."):
		return _failure("PARSE_INVALID_COEFFICIENT", "Stoichiometric coefficient must be a positive integer.", formula_offset, mini(global_start + raw_text.length(), formula_offset + 1))
	var coefficient := 1
	var digit_count := 0
	while digit_count < text.length() and text.substr(digit_count, 1).is_valid_int():
		digit_count += 1
	if digit_count > 0:
		var coefficient_text := text.substr(0, digit_count)
		var parsed_coefficient := _parse_bounded_integer(coefficient_text, MAX_INTEGER_TOKEN)
		if parsed_coefficient < 0:
			return _failure("PARSE_COEFFICIENT_TOO_LARGE", "Stoichiometric coefficient exceeds the configured safe limit.", formula_offset, formula_offset + digit_count)
		coefficient = parsed_coefficient
		if digit_count < text.length() and text.substr(digit_count, 1) == ".":
			return _failure("PARSE_INVALID_COEFFICIENT", "Fractional stoichiometric coefficients are not supported.", formula_offset + digit_count, formula_offset + digit_count + 1)
		if coefficient <= 0:
			return _failure("PARSE_INVALID_COEFFICIENT", "Stoichiometric coefficient must be a positive integer.", formula_offset, formula_offset + digit_count)
		var formula_remainder := text.substr(digit_count)
		var formula_text := formula_remainder.strip_edges()
		if formula_text.is_empty():
			return _failure("PARSE_EMPTY_FORMULA", "A coefficient must be followed by a formula.", global_start, global_start + raw_text.length())
		formula_offset = global_start + leading + digit_count + formula_remainder.find(formula_text)
		text = formula_text
	

	var formula_result := parse_formula(text)
	if not formula_result.ok:
		var local_span: Dictionary = formula_result.get("source_span", {"start_offset": 0, "end_offset": text.length()})
		var error_start := formula_offset + int(local_span.get("start_offset", 0))
		var error_end := formula_offset + int(local_span.get("end_offset", text.length()))
		return _failure(formula_result.code, formula_result.message, error_start, error_end)
	var ast: Dictionary = formula_result.formula_ast
	var phase: String = formula_result.phase
	return {
		"ok": true,
		"term": {
			"term_id": "term_%d" % global_start,
			"species": {
				"formula_ast": ast,
				"phase": phase
			},
			"stoichiometric_coefficient": coefficient,
			"source_span": {"start_offset": global_start, "end_offset": global_start + raw_text.length()}
		}
	}

func _extract_charge(text: String) -> Dictionary:
	# Caret notation has priority: Fe^3+ and SO4^2− must not be mistaken
	# for an ambiguous simple-charge suffix after a subscript.
	var caret := text.rfind("^")
	if caret >= 0:
		var suffix := text.substr(caret + 1)
		if suffix.is_empty():
			return {"ok": false, "code": "PARSE_INVALID_CHARGE", "message": "Charge marker must be followed by an optional magnitude and a sign.", "error_offset": caret + 1}
		var sign_text := suffix.substr(suffix.length() - 1, 1)
		if sign_text != "+" and sign_text != "-" and sign_text != "−":
			return {"ok": false, "code": "PARSE_INVALID_CHARGE", "message": "Charge must end with + or -.", "error_offset": caret + 1 + suffix.length() - 1}
		var magnitude_text := suffix.substr(0, suffix.length() - 1)
		var magnitude := 1
		if not magnitude_text.is_empty():
			for digit_index in range(magnitude_text.length()):
				var digit_text := magnitude_text.substr(digit_index, 1)
				if digit_text < "0" or digit_text > "9":
					return {"ok": false, "code": "PARSE_INVALID_CHARGE", "message": "Charge magnitude must contain decimal digits only.", "error_offset": caret + 1 + digit_index}
			magnitude = _parse_bounded_integer(magnitude_text, MAX_INTEGER_TOKEN)
			if magnitude < 0:
				return {"ok": false, "code": "PARSE_CHARGE_TOO_LARGE", "message": "Charge magnitude exceeds the configured safe limit.", "error_offset": caret + 1}
		if magnitude <= 0:
			return {"ok": false, "code": "PARSE_INVALID_CHARGE", "message": "Charge magnitude must be positive.", "error_offset": caret + 1}
		return {"ok": true, "body": text.substr(0, caret), "charge": magnitude if sign_text == "+" else -magnitude}

	if text.ends_with("+") or text.ends_with("-") or text.ends_with("−"):
		var sign := 1 if text.ends_with("+") else -1
		if SIMPLE_ION_ALIASES.has(text):
			return {"ok": true, "body": text.substr(0, text.length() - 1), "charge": sign}
		if text.length() >= 2 and text.substr(text.length() - 2, 1).is_valid_int():
			return {"ok": false, "code": "PARSE_AMBIGUOUS_CHARGE", "message": "Use caret notation for a multi-charge ion; this suffix is ambiguous."}
		return {"ok": true, "body": text.substr(0, text.length() - 1), "charge": sign}

	return {"ok": true, "body": text, "charge": 0}

func _parse_sequence(text: String, state: Dictionary, nested: bool, opening_group_start: int = -1) -> Array:
	var nodes: Array = []
	while int(state.index) < text.length():
		var ch := text.substr(int(state.index), 1)
		if ch == ")":
			if nested:
				state.index = int(state.index) + 1
				return nodes
			state.error_index = int(state.index)
			state.error = "PARSE_UNEXPECTED_TOKEN"
			return nodes
		if ch == "(":
			var group_start := int(state.index)
			state.depth = int(state.depth) + 1
			if int(state.depth) > MAX_GROUP_DEPTH:
				state.error_index = group_start
				state.error = "PARSE_NESTING_LIMIT"
				return nodes
			state.index = int(state.index) + 1
			var children := _parse_sequence(text, state, true, group_start)
			state.depth = int(state.depth) - 1
			if not String(state.error).is_empty():
				return nodes
			if int(state.index) == 0 or text.substr(int(state.index) - 1, 1) != ")":
				state.error_index = group_start
				state.error = "PARSE_UNCLOSED_GROUP"
				return nodes
			if children.is_empty():
				state.error_index = group_start
				state.error = "PARSE_EMPTY_GROUP"
				return nodes
			var group_count := _read_count(text, state)
			if group_count < 0:
				return nodes
			nodes.append({"type": "group", "children": children, "multiplier": group_count})
			continue
		if ch >= "A" and ch <= "Z":
			var symbol_start := int(state.index)
			var symbol := ch
			state.index = int(state.index) + 1
			if int(state.index) < text.length():
				var next_ch := text.substr(int(state.index), 1)
				if next_ch >= "a" and next_ch <= "z":
					symbol += next_ch
					state.index = int(state.index) + 1
			if not ELEMENTS.has(symbol):
				state.error_index = symbol_start
				state.error = "PARSE_UNKNOWN_ELEMENT"
				return nodes
			var count := _read_count(text, state)
			if count < 0:
				return nodes
			nodes.append({"type": "element", "symbol": symbol, "count": count})
			continue
		if ch.is_valid_int():
			state.error_index = int(state.index)
			state.error = "PARSE_UNEXPECTED_TOKEN"
			return nodes
		state.error_index = int(state.index)
		state.error = "PARSE_UNSUPPORTED_SYNTAX" if ch == "·" or ch == "[" or ch == "]" else "PARSE_UNEXPECTED_TOKEN"
		return nodes
	if nested:
		state.error_index = opening_group_start
		state.error = "PARSE_UNCLOSED_GROUP"
	return nodes

func _read_count(text: String, state: Dictionary) -> int:
	var start := int(state.index)
	while int(state.index) < text.length() and text.substr(int(state.index), 1).is_valid_int():
		state.index = int(state.index) + 1
	if int(state.index) == start:
		return 1
	var value := _parse_bounded_integer(text.substr(start, int(state.index) - start), MAX_INTEGER_TOKEN)
	if value < 0:
		state.error_index = start
		state.error = "PARSE_COUNT_TOO_LARGE"
		return -1
	if value == 0:
		state.error_index = start
		state.error = "PARSE_ZERO_COUNT"
		return -1
	return value

func _parse_bounded_integer(digits: String, limit: int) -> int:
	if limit < 0 or digits.is_empty():
		return -1
	var value := 0
	for i in range(digits.length()):
		var character := digits.substr(i, 1)
		if character < "0" or character > "9":
			return -1
		var digit := int(character)
		# Check before multiplication so even very long tokens cannot overflow
		# the machine integer and wrap back into the accepted range.
		var quotient := int(limit / 10)
		if value > quotient or (value == quotient and digit > limit % 10):
			return -1
		value = value * 10 + digit
	return value

func _expand_nodes(nodes: Array, state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node in nodes:
		if node.type == "element":
			var symbol := String(node.symbol)
			var addition := int(node.count)
			var total := int(result.get(symbol, 0)) + addition
			if total > MAX_COMPOSITION_COUNT:
				state.overflow = true
				return {}
			result[symbol] = total
		else:
			var nested: Dictionary = _expand_nodes(node.children, state)
			if bool(state.overflow):
				return {}
			for element in nested:
				var multiplied := int(nested[element]) * int(node.multiplier)
				if multiplied > MAX_COMPOSITION_COUNT or int(result.get(element, 0)) > MAX_COMPOSITION_COUNT - multiplied:
					state.overflow = true
					return {}
				result[element] = int(result.get(element, 0)) + multiplied
	return result

func _is_valid_reaction_term(term: Variant) -> bool:
	if typeof(term) != TYPE_DICTIONARY:
		return false
	var species: Variant = term.get("species")
	if typeof(species) != TYPE_DICTIONARY:
		return false
	var ast: Variant = species.get("formula_ast")
	if typeof(ast) != TYPE_DICTIONARY or typeof(ast.get("element_counts")) != TYPE_DICTIONARY or typeof(ast.get("nodes")) != TYPE_ARRAY:
		return false
	if typeof(ast.get("schema_version")) != TYPE_INT or int(ast.schema_version) != 1:
		return false
	if typeof(ast.get("source_text")) != TYPE_STRING or String(ast.source_text).is_empty():
		return false
	if typeof(ast.get("net_charge")) != TYPE_INT or abs(int(ast.net_charge)) > MAX_INTEGER_TOKEN:
		return false
	if ast.element_counts.is_empty():
		return false
	var phase: Variant = species.get("phase", "UNSPECIFIED")
	if typeof(phase) != TYPE_STRING or not ["UNSPECIFIED", "SOLID", "LIQUID", "GAS", "AQUEOUS"].has(String(phase)):
		return false
	for element in ast.element_counts:
		if typeof(element) != TYPE_STRING or typeof(ast.element_counts[element]) != TYPE_INT:
			return false
		if int(ast.element_counts[element]) <= 0 or int(ast.element_counts[element]) > MAX_COMPOSITION_COUNT:
			return false

	# FormulaAST is a derived value, not an independent source of truth.
	# Reparse the preserved formula so stale or caller-mutated counts/charge
	# cannot make check_balance report a false positive.
	var reparsed := parse_formula(String(ast.source_text))
	if not bool(reparsed.get("ok", false)) or String(reparsed.phase) != String(phase):
		return false
	var parsed_ast: Dictionary = reparsed.formula_ast
	if int(parsed_ast.net_charge) != int(ast.net_charge) or parsed_ast.element_counts != ast.element_counts or parsed_ast.nodes != ast.nodes:
		return false

	var coefficient: Variant = term.get("stoichiometric_coefficient", 1)
	if typeof(coefficient) != TYPE_INT or int(coefficient) <= 0 or int(coefficient) > MAX_INTEGER_TOKEN:
		return false
	return true

func _find_arrow(source: String) -> Dictionary:
	var found := ""
	var found_pos := -1
	var index := 0
	while index < source.length():
		var matched := ""
		for candidate in ["<->", "⇌", "->", "→"]:
			if source.substr(index, candidate.length()) == candidate:
				matched = candidate
				break
		if not matched.is_empty():
			if found_pos >= 0:
				return {"ok": false, "code": "PARSE_MULTIPLE_ARROWS", "message": "Reaction must contain exactly one arrow.", "position": index, "end_position": index + matched.length()}
			found = matched
			found_pos = index
			index += matched.length()
		else:
			index += 1
	if found_pos < 0:
		return {"ok": false, "code": "PARSE_MISSING_ARROW", "message": "Reaction arrow is missing.", "position": source.length(), "end_position": source.length()}
	return {"ok": true, "arrow": found, "position": found_pos}

func _split_side(side: String) -> Dictionary:
	var parts: Array = []
	var start := 0
	for i in range(side.length()):
		if side.substr(i, 1) != "+" or i == 0 or i == side.length() - 1:
			continue
		var left_ws := side.substr(i - 1, 1).strip_edges().is_empty()
		var right_ws := side.substr(i + 1, 1).strip_edges().is_empty()
		if left_ws and right_ws:
			var raw := side.substr(start, i - start)
			if raw.strip_edges().is_empty():
				return {"ok": false, "code": "PARSE_INVALID_SEPARATOR", "message": "Empty reaction term around '+' separator.", "position": i, "end_position": i + 1}
			parts.append({"text": raw, "start": start})
			start = i + 1
	if side.substr(start).strip_edges().is_empty():
		var empty_position := start
		while empty_position < side.length() and side.substr(empty_position, 1).strip_edges().is_empty():
			empty_position += 1
		return {"ok": false, "code": "PARSE_EMPTY_SIDE", "message": "Reaction side is empty.", "position": empty_position, "end_position": empty_position}
	parts.append({"text": side.substr(start), "start": start})
	return {"ok": true, "parts": parts}

func _failure(code: String, message: String, start: int, end: int) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "source_span": {"start_offset": start, "end_offset": end}, "diagnostics": [{"code": code, "severity": "ERROR", "message": message, "source_span": {"start_offset": start, "end_offset": end}}]}

func _message_for(code: String) -> String:
	match code:
		"PARSE_UNKNOWN_ELEMENT": return "Unknown chemical element symbol."
		"PARSE_UNCLOSED_GROUP": return "A parenthesis group is not closed."
		"PARSE_ZERO_COUNT": return "Subscripts and group multipliers must be positive integers."
		"PARSE_EMPTY_GROUP": return "Empty parenthesis groups are not allowed."
		"PARSE_NESTING_LIMIT": return "Formula nesting exceeds the configured limit."
		"PARSE_COUNT_TOO_LARGE": return "Subscript or group multiplier exceeds the configured safe limit."
		"PARSE_COUNT_OVERFLOW": return "Expanded element count exceeds the configured safe limit."
		"PARSE_FORMULA_TOO_LONG": return "Formula exceeds the configured length limit."
		"PARSE_UNSUPPORTED_SYNTAX": return "This chemical notation is outside the MVP grammar."
		_: return "Unexpected token in formula."
