class_name BalanceResult
extends RefCounted

var ok: bool = false
var status: String = "invalid_input"
var coefficients: Array[int] = []
var diagnostics: Array[String] = []
var error_code: String = ""
var error_message: String = ""

static func success(values: Array[int]) -> BalanceResult:
	var result := BalanceResult.new()
	result.ok = true
	result.status = "balanced"
	result.coefficients = values.duplicate()
	return result

static func failure(status_value: String, code: String, message: String) -> BalanceResult:
	var result := BalanceResult.new()
	result.status = status_value
	result.error_code = code
	result.error_message = message
	result.diagnostics.append(message)
	return result
