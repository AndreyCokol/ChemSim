class_name ReactionParseResult
extends RefCounted

var ok: bool = false
var arrow: String = ""
var reactants: Array[Dictionary] = []
var products: Array[Dictionary] = []
var error_code: String = ""
var error_message: String = ""

static func success(arrow_value: String, left: Array[Dictionary], right: Array[Dictionary]) -> ReactionParseResult:
	var result := ReactionParseResult.new()
	result.ok = true
	result.arrow = arrow_value
	result.reactants = left.duplicate(true)
	result.products = right.duplicate(true)
	return result

static func failure(code: String, message: String) -> ReactionParseResult:
	var result := ReactionParseResult.new()
	result.error_code = code
	result.error_message = message
	return result
