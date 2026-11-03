extends SceneTree

const FormulaParserScript = preload("res://scripts/domain/formula_parser.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_formula("H2O", {"H": 2, "O": 1}, 0, "")
	_test_formula("Ca(OH)2", {"Ca": 1, "O": 2, "H": 2}, 0, "")
	_test_formula("Al2(SO4)3", {"Al": 2, "S": 3, "O": 12}, 0, "")
	_test_formula("SO4^2-(aq)", {"S": 1, "O": 4}, -2, "aq")
	_test_formula("Fe^3+(aq)", {"Fe": 1}, 3, "aq")
	_test_formula("H+", {"H": 1}, 1, "")
	_test_invalid("Fe3+", "PARSER_AMBIGUOUS_CHARGE")
	_test_invalid("Ca(OH2", "PARSER_UNCLOSED_GROUP")
	_test_invalid("H0", "PARSER_INVALID_INDEX")
	_test_invalid("Xx2", "PARSER_UNKNOWN_ELEMENT")
	_test_invalid("NaCl·2H2O", "PARSER_UNSUPPORTED_SYNTAX")
	_test_invalid("H1000000H", "PARSER_COUNT_LIMIT")
	_test_invalid("H1000001", "PARSER_COUNT_LIMIT")
	_test_invalid("Fe^12345678+", "PARSER_CHARGE_LIMIT")
	_test_resource_limits()

	if _failures.is_empty():
		print("PASS: formula parser tests")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _test_resource_limits() -> void:
	var deep_formula := "H" + "(".repeat(33) + "O" + ")".repeat(33)
	_test_invalid(deep_formula, "PARSER_NESTING_LIMIT")
	_test_invalid("H".repeat(257), "PARSER_INPUT_LIMIT")

func _test_formula(source: String, expected: Dictionary, charge: int, phase: String) -> void:
	var result = FormulaParserScript.new().parse(source)
	if not result.ok:
		_failures.append("%s unexpectedly failed: %s %s" % [source, result.error_code, result.error_message])
		return
	if result.element_counts != expected or result.net_charge != charge or result.phase != phase:
		_failures.append("%s mismatch: %s" % [source, result.to_dictionary()])

func _test_invalid(source: String, expected_code: String) -> void:
	var result = FormulaParserScript.new().parse(source)
	if result.ok or result.error_code != expected_code:
		_failures.append("%s expected %s, got %s" % [source, expected_code, result.error_code])
