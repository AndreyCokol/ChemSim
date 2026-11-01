extends SceneTree

const ReactionParserScript = preload("res://scripts/domain/reaction_parser.gd")
const ReactionBalancerScript = preload("res://scripts/domain/reaction_balancer.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_balance("H2 + O2 -> H2O", [2, 1, 2])
	_test_balance("Fe + O2 -> Fe2O3", [4, 3, 2])
	_test_balance("H+ + OH- -> H2O", [1, 1, 1])
	_test_balance("2 H2 + O2 -> 2 H2O", [2, 1, 2])
	_test_parse_invalid("H2 + -> H2O", "REACTION_EMPTY_TERM")
	_test_parse_invalid("H2 + O2", "REACTION_ARROW_REQUIRED")
	_test_parse_invalid("H2 ->", "REACTION_EMPTY_SIDE")
	_test_parse_invalid("H2 + O2 -> H2O -> H2O", "REACTION_MULTIPLE_ARROWS")
	_test_parse_invalid("H2 <-> O2 -> H2O", "REACTION_MULTIPLE_ARROWS")
	_test_parse_invalid("H2 + O2 -> H2O <-> H2O", "REACTION_MULTIPLE_ARROWS")
	_test_balance_status("H2 + O2 -> H2", "no_positive_solution")
	_test_balance_status("H2 + O2 -> H2O + H2O", "ambiguous")

	if _failures.is_empty():
		print("PASS: reaction parser and balancer tests")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _test_balance(source: String, expected: Array[int]) -> void:
	var parsed = ReactionParserScript.new().parse(source)
	if not parsed.ok:
		_failures.append("%s parse failed: %s %s" % [source, parsed.error_code, parsed.error_message])
		return
	var result = ReactionBalancerScript.new().balance(parsed)
	if not result.ok or result.coefficients != expected:
		_failures.append("%s expected %s, got status=%s coefficients=%s error=%s" % [source, expected, result.status, result.coefficients, result.error_message])

func _test_parse_invalid(source: String, expected_code: String) -> void:
	var result = ReactionParserScript.new().parse(source)
	if result.ok or result.error_code != expected_code:
		_failures.append("%s expected %s, got %s" % [source, expected_code, result.error_code])

func _test_balance_status(source: String, expected_status: String) -> void:
	var parsed = ReactionParserScript.new().parse(source)
	if not parsed.ok:
		_failures.append("%s parse failed unexpectedly: %s" % [source, parsed.error_message])
		return
	var result = ReactionBalancerScript.new().balance(parsed)
	if result.status != expected_status:
		_failures.append("%s expected status %s, got %s (%s)" % [source, expected_status, result.status, result.error_message])
