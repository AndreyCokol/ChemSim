class_name ReactionParser
extends RefCounted

const FormulaParserScript = preload("res://scripts/domain/formula_parser.gd")

func parse(input: String) -> ReactionParseResult:
	var source := input.strip_edges()
	if source.is_empty():
		return ReactionParseResult.failure("REACTION_EMPTY", "Введите уравнение реакции.")

	var arrow := ""
	var arrow_index := -1
	if source.contains("<->"):
		arrow = "<->"
		arrow_index = source.find("<->")
	if source.contains("->"):
		if not arrow.is_empty():
			return ReactionParseResult.failure("REACTION_MULTIPLE_ARROWS", "В уравнении найдено несколько типов стрелок.")
		arrow = "->"
		arrow_index = source.find("->")
	if arrow.is_empty():
		return ReactionParseResult.failure("REACTION_ARROW_REQUIRED", "Используйте стрелку -> или <->.")
	if source.find(arrow, arrow_index + arrow.length()) >= 0:
		return ReactionParseResult.failure("REACTION_MULTIPLE_ARROWS", "Уравнение должно содержать ровно одну стрелку.")

	var left_text := source.substr(0, arrow_index).strip_edges()
	var right_text := source.substr(arrow_index + arrow.length()).strip_edges()
	if left_text.is_empty() or right_text.is_empty():
		return ReactionParseResult.failure("REACTION_EMPTY_SIDE", "Слева и справа от стрелки должны быть вещества.")

	var left_result := _parse_side(left_text)
	if not left_result.ok:
		return left_result
	var right_result := _parse_side(right_text)
	if not right_result.ok:
		return right_result
	return ReactionParseResult.success(arrow, left_result.reactants, right_result.reactants)

func _parse_side(side_text: String) -> ReactionParseResult:
	var separator := RegEx.new()
	separator.compile("\\s+\\+\\s+")
	var pieces := separator.split(side_text)
	if pieces.is_empty():
		return ReactionParseResult.failure("REACTION_EMPTY_SIDE", "Сторона реакции не содержит веществ.")

	var terms: Array[Dictionary] = []
	for raw_piece in pieces:
		var piece := raw_piece.strip_edges()
		if piece.is_empty():
			return ReactionParseResult.failure("REACTION_EMPTY_TERM", "Между разделителями обнаружен пустой член реакции.")
		var coefficient := 1
		var formula := piece
		var coefficient_match := RegEx.new()
		coefficient_match.compile("^([0-9]+)\\s+(.+)$")
		var matched := coefficient_match.search(piece)
		if matched:
			coefficient = int(matched.get_string(1))
			formula = matched.get_string(2).strip_edges()
			if coefficient <= 0:
				return ReactionParseResult.failure("REACTION_INVALID_COEFFICIENT", "Коэффициент должен быть положительным целым числом.")
		var parsed: FormulaParseResult = FormulaParserScript.new().parse(formula)
		if not parsed.ok:
			return ReactionParseResult.failure(parsed.error_code, "%s: %s" % [formula, parsed.error_message])
		terms.append({
			"coefficient": coefficient,
			"formula": formula,
			"element_counts": parsed.element_counts,
			"net_charge": parsed.net_charge,
			"phase": parsed.phase
		})
	return ReactionParseResult.success("", terms, [])
