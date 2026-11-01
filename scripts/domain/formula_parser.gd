class_name FormulaParser
extends RefCounted

const ELEMENTS := {
	"H": true, "He": true, "Li": true, "Be": true, "B": true, "C": true, "N": true, "O": true, "F": true, "Ne": true,
	"Na": true, "Mg": true, "Al": true, "Si": true, "P": true, "S": true, "Cl": true, "Ar": true, "K": true, "Ca": true,
	"Sc": true, "Ti": true, "V": true, "Cr": true, "Mn": true, "Fe": true, "Co": true, "Ni": true, "Cu": true, "Zn": true,
	"Ga": true, "Ge": true, "As": true, "Se": true, "Br": true, "Kr": true, "Rb": true, "Sr": true, "Y": true, "Zr": true,
	"Nb": true, "Mo": true, "Tc": true, "Ru": true, "Rh": true, "Pd": true, "Ag": true, "Cd": true, "In": true, "Sn": true,
	"Sb": true, "Te": true, "I": true, "Xe": true, "Cs": true, "Ba": true, "La": true, "Ce": true, "Pr": true, "Nd": true,
	"Pm": true, "Sm": true, "Eu": true, "Gd": true, "Tb": true, "Dy": true, "Ho": true, "Er": true, "Tm": true, "Yb": true,
	"Lu": true, "Hf": true, "Ta": true, "W": true, "Re": true, "Os": true, "Ir": true, "Pt": true, "Au": true, "Hg": true,
	"Tl": true, "Pb": true, "Bi": true, "Po": true, "At": true, "Rn": true, "Fr": true, "Ra": true, "Ac": true, "Th": true,
	"Pa": true, "U": true, "Np": true, "Pu": true, "Am": true, "Cm": true, "Bk": true, "Cf": true, "Es": true, "Fm": true,
	"Md": true, "No": true, "Lr": true, "Rf": true, "Db": true, "Sg": true, "Bh": true, "Hs": true, "Mt": true, "Ds": true,
	"Rg": true, "Cn": true, "Nh": true, "Fl": true, "Mc": true, "Lv": true, "Ts": true, "Og": true
}

var _source: String = ""
var _index: int = 0
var _error_code: String = ""
var _error_message: String = ""

func parse(input: String) -> FormulaParseResult:
	_source = input.strip_edges()
	_index = 0
	_error_code = ""
	_error_message = ""
	if _source.is_empty():
		return FormulaParseResult.failure("PARSER_EMPTY_FORMULA", "Введите химическую формулу.")

	var phase := ""
	for candidate in ["(aq)", "(s)", "(l)", "(g)"]:
		if _source.ends_with(candidate):
			phase = candidate.substr(1, candidate.length() - 2)
			_source = _source.substr(0, _source.length() - candidate.length())
			break

	var charge := 0
	var charge_match := RegEx.new()
	charge_match.compile("\\^([0-9]*)([+-])$")
	var match_result := charge_match.search(_source)
	if match_result:
		var magnitude_text: String = match_result.get_string(1)
		var magnitude := 1 if magnitude_text.is_empty() else int(magnitude_text)
		if magnitude <= 0:
			return FormulaParseResult.failure("PARSER_INVALID_CHARGE", "Модуль заряда должен быть положительным.")
		charge = magnitude if match_result.get_string(2) == "+" else -magnitude
		_source = _source.substr(0, match_result.get_start())
	elif _source.ends_with("+") or _source.ends_with("-"):
		# Краткая запись H+, OH−, Ag+; цифра перед знаком остаётся индексом,
		# поэтому неоднозначная одноэлементная запись Fe3+ запрещена ниже.
		var sign := _source.substr(_source.length() - 1, 1)
		var body := _source.substr(0, _source.length() - 1)
		var ambiguous := RegEx.new()
		ambiguous.compile("^[A-Z][a-z]?[0-9]+$")
		if ambiguous.search(body):
			return FormulaParseResult.failure("PARSER_AMBIGUOUS_CHARGE", "Неоднозначный заряд. Используйте запись с кареткой, например Fe^3+.")
		charge = 1 if sign == "+" else -1
		_source = body

	if _source.is_empty():
		return FormulaParseResult.failure("PARSER_INVALID_FORMULA", "После выделения заряда формула оказалась пустой.")
	if not _source[0].to_upper() == _source[0] or not _source[0].is_valid_ascii_identifier():
		return FormulaParseResult.failure("PARSER_UNSUPPORTED_SYNTAX", "Формула должна начинаться с символа химического элемента.")

	var counts := _parse_group(false)
	if not _error_code.is_empty():
		return FormulaParseResult.failure(_error_code, _error_message)
	if _index != _source.length():
		return FormulaParseResult.failure("PARSER_UNSUPPORTED_SYNTAX", "Неожиданный символ «%s» в позиции %d." % [_source.substr(_index, 1), _index + 1])
	if counts.is_empty():
		return FormulaParseResult.failure("PARSER_EMPTY_FORMULA", "Формула не содержит химических элементов.")

	return FormulaParseResult.success(input.strip_edges(), counts, charge, phase)

func _parse_group(nested: bool) -> Dictionary:
	var result: Dictionary = {}
	var token_count := 0
	while _index < _source.length():
		var ch := _source.substr(_index, 1)
		if ch == ")":
			if not nested:
				_fail("PARSER_UNEXPECTED_TOKEN", "Лишняя закрывающая скобка.")
				return result
			_index += 1
			return result
		if ch == "(":
			_index += 1
			var inner := _parse_group(true)
			if not _error_code.is_empty():
				return result
			if inner.is_empty():
				_fail("PARSER_EMPTY_GROUP", "Пустые группы не поддерживаются.")
				return result
			var multiplier := _parse_positive_integer()
			for element in inner:
				result[element] = int(result.get(element, 0)) + int(inner[element]) * multiplier
			token_count += 1
			continue
		if ch >= "A" and ch <= "Z":
			var symbol := ch
			_index += 1
			if _index < _source.length():
				var next_ch := _source.substr(_index, 1)
				if next_ch >= "a" and next_ch <= "z":
					symbol += next_ch
					_index += 1
			if not ELEMENTS.has(symbol):
				_fail("PARSER_UNKNOWN_ELEMENT", "Неизвестный символ элемента «%s»." % symbol)
				return result
			var amount := _parse_positive_integer()
			result[symbol] = int(result.get(symbol, 0)) + amount
			token_count += 1
			continue
		if ch >= "0" and ch <= "9":
			_fail("PARSER_INVALID_INDEX", "Индекс должен следовать за элементом или группой.")
			return result
		_fail("PARSER_UNSUPPORTED_SYNTAX", "Символ «%s» не поддерживается в формуле MVP." % ch)
		return result

	if nested:
		_fail("PARSER_UNCLOSED_GROUP", "Не закрыта круглая скобка.")
	return result

func _parse_positive_integer() -> int:
	var start := _index
	while _index < _source.length():
		var ch := _source.substr(_index, 1)
		if ch < "0" or ch > "9":
			break
		_index += 1
	if start == _index:
		return 1
	var value := int(_source.substr(start, _index - start))
	if value <= 0:
		_fail("PARSER_INVALID_INDEX", "Индекс элемента или группы должен быть положительным.")
		return 1
	return value

func _fail(code: String, message: String) -> void:
	if _error_code.is_empty():
		_error_code = code
		_error_message = message
