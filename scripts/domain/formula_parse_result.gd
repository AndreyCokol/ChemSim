class_name FormulaParseResult
extends RefCounted

var ok: bool = false
var canonical_formula: String = ""
var element_counts: Dictionary = {}
var net_charge: int = 0
var phase: String = ""
var error_code: String = ""
var error_message: String = ""

static func success(formula: String, counts: Dictionary, charge: int, phase_value: String) -> FormulaParseResult:
	var result := FormulaParseResult.new()
	result.ok = true
	result.canonical_formula = formula
	result.element_counts = counts.duplicate(true)
	result.net_charge = charge
	result.phase = phase_value
	return result

static func failure(code: String, message: String) -> FormulaParseResult:
	var result := FormulaParseResult.new()
	result.ok = false
	result.error_code = code
	result.error_message = message
	return result

func to_dictionary() -> Dictionary:
	return {
		"ok": ok,
		"canonical_formula": canonical_formula,
		"element_counts": element_counts.duplicate(true),
		"net_charge": net_charge,
		"phase": phase,
		"error_code": error_code,
		"error_message": error_message
	}
