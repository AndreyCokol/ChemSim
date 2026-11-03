class_name A1UnitGate
extends RefCounted

## A1-local registered-unit conversion preflight for the approved v0.1 set.
## This is NOT scientific model applicability, a chemistry parser, or wire DTO.
## Requiring a dimension and basis is intentional: no molality↔molarity,
## K↔kinetic k, mass↔amount, or guessed pressure/temperature conventions.

const UNIT_DEFS: Dictionary = {
	"1": {"dimension": "dimensionless", "scale": 1.0},
	"mol": {"dimension": "amount", "scale": 1.0},
	"kg": {"dimension": "mass", "scale": 1.0},
	"g": {"dimension": "mass", "scale": 0.001},
	"m3": {"dimension": "volume", "scale": 1.0},
	"L": {"dimension": "volume", "scale": 0.001},
	"s": {"dimension": "time", "scale": 1.0},
	"K": {"dimension": "temperature", "scale": 1.0},
	"degC": {"dimension": "temperature", "scale": 1.0},
	"Pa": {"dimension": "pressure", "scale": 1.0},
	"bar": {"dimension": "pressure", "scale": 100000.0},
	"mol/m3": {"dimension": "concentration", "scale": 1.0},
	"mol/L": {"dimension": "concentration", "scale": 1000.0},
	"mol/s": {"dimension": "amount_rate", "scale": 1.0},
	"mol/(m3*s)": {"dimension": "volumetric_rate", "scale": 1.0},
	"J/mol": {"dimension": "molar_energy", "scale": 1.0}
}
const BASIS_REQUIRED_DIMENSIONS: Array[String] = [
	"dimensionless", "concentration", "pressure",
	"amount_rate", "volumetric_rate", "molar_energy"
]
const VALID_STATUSES: Array[String] = [
	"present", "unknown", "not_reported",
	"not_assessed", "not_applicable", "withheld"
]

static func convert_quantity(quantity: Variant, target_unit_id: String, required: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if not quantity is Dictionary:
		return _failure("A1_UNIT_QUANTITY_INVALID")
	for key in required:
		if not ["dimension_id", "basis", "temperature_kind"].has(key):
			_flag(errors, "A1_UNIT_REQUIREMENT_FIELD_UNSUPPORTED")
	for key in quantity:
		if not ["value", "unit_id", "basis", "uncertainty"].has(key):
			_flag(errors, "A1_UNIT_QUANTITY_FIELD_UNSUPPORTED")

	var from_id: Variant = quantity.get("unit_id")
	if not UNIT_DEFS.has(from_id) or not UNIT_DEFS.has(target_unit_id):
		_flag(errors, "A1_UNIT_UNREGISTERED")
		return _failed(errors)
	var dimension: String = UNIT_DEFS[from_id]["dimension"]
	if UNIT_DEFS[target_unit_id]["dimension"] != dimension:
		_flag(errors, "A1_UNIT_DIMENSION_MISMATCH")

	var expected_dimension: Variant = required.get("dimension_id")
	if expected_dimension != dimension:
		_flag(errors, "A1_UNIT_REQUIREMENT_MISMATCH")

	var original_value: Variant = quantity.get("value")
	if not _finite_number(original_value):
		_flag(errors, "A1_UNIT_VALUE_INVALID")
	var actual_basis: Variant = quantity.get("basis")
	var required_basis: Variant = required.get("basis")
	if quantity.has("basis") or required.has("basis") or BASIS_REQUIRED_DIMENSIONS.has(dimension):
		if not _nonempty(actual_basis) or not _nonempty(required_basis):
			_flag(errors, "A1_UNIT_BASIS_MISSING")
		elif actual_basis != required_basis:
			_flag(errors, "A1_UNIT_BASIS_MISMATCH")

	if dimension == "temperature":
		if required.get("temperature_kind") != "absolute":
			_flag(errors, "A1_UNIT_TEMPERATURE_KIND_UNSUPPORTED")
	elif required.has("temperature_kind"):
		_flag(errors, "A1_UNIT_TEMPERATURE_KIND_NOT_APPLICABLE")

	var value: float = 0.0
	if errors.is_empty():
		var converted: Dictionary = _convert_scalar(float(original_value), String(from_id), target_unit_id)
		if not converted["ok"]:
			_flag(errors, String(converted["error"]))
		else:
			value = converted["value"]

	# Quantity.uncertainty is an Availability, not a scalar. Never silently
	# discard a present uncertainty, or add affine offsets to an interval.
	var updated_uncertainty: Variant = null
	if quantity.has("uncertainty"):
		var uncertainty: Variant = quantity["uncertainty"]
		if not uncertainty is Dictionary:
			_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
		else:
			var uncertainty_status: Variant = uncertainty.get("status")
			if uncertainty.size() != 1 and uncertainty_status != "present":
				_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
			if not VALID_STATUSES.has(uncertainty_status):
				_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
			elif uncertainty_status != "present":
				if uncertainty.has("quantity"):
					_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
				else:
					updated_uncertainty = {"status": uncertainty_status}
			else:
				if uncertainty.size() != 2:
					_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
				var uncertainty_quantity: Variant = uncertainty.get("quantity")
				if not uncertainty_quantity is Dictionary:
					_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
				else:
					if dimension == "temperature":
						# No distinct temperature-difference ID in v0.1 registry.
						_flag(errors, "A1_UNIT_TEMPERATURE_UNCERTAINTY_UNSUPPORTED")
					for field in uncertainty_quantity:
						if not ["value", "unit_id", "basis"].has(field):
							_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
					if uncertainty_quantity.get("unit_id") != from_id or not _finite_number(uncertainty_quantity.get("value")):
						_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
					elif float(uncertainty_quantity["value"]) < 0.0:
						_flag(errors, "A1_UNIT_UNCERTAINTY_INVALID")
					if uncertainty_quantity.has("basis") != quantity.has("basis") or uncertainty_quantity.get("basis") != actual_basis:
						_flag(errors, "A1_UNIT_UNCERTAINTY_BASIS_MISMATCH")
					if errors.is_empty():
						var result: Dictionary = _convert_linear(float(uncertainty_quantity["value"]), String(from_id), target_unit_id)
						if not result["ok"]:
							_flag(errors, String(result["error"]))
						else:
							var converted_uncertainty: Dictionary = {"value": result["value"], "unit_id": target_unit_id}
							if quantity.has("basis"):
								converted_uncertainty["basis"] = actual_basis
							updated_uncertainty = {"status": "present", "quantity": converted_uncertainty}

	if not errors.is_empty():
		return _failed(errors)
	var output: Dictionary = {"value": value, "unit_id": target_unit_id}
	if quantity.has("basis"):
		output["basis"] = actual_basis
	if quantity.has("uncertainty"):
		output["uncertainty"] = updated_uncertainty
	return {
		"ok": true,
		"errors": [],
		"quantity": output,
		"scope": "a1_unit_conversion_only"
	}


static func convert_availability(availability: Variant, target_unit_id: String, required: Dictionary) -> Dictionary:
	if not availability is Dictionary:
		return _failure("A1_UNIT_AVAILABILITY_INVALID")
	if not VALID_STATUSES.has(availability.get("status")):
		return _failure("A1_UNIT_AVAILABILITY_INVALID")
	# Even unavailable data cannot authorize an unregistered destination or
	# incorrect expected dimension: never fabricate a convertible unit.
	if not UNIT_DEFS.has(target_unit_id):
		return _failure("A1_UNIT_UNREGISTERED")
	if required.get("dimension_id") != UNIT_DEFS[target_unit_id]["dimension"]:
		return _failure("A1_UNIT_REQUIREMENT_MISMATCH")
	var status: String = availability["status"]
	if status != "present":
		if availability.size() != 1 or availability.has("quantity"):
			return _failure("A1_UNIT_AVAILABILITY_INVALID")
		# An unknown/withheld quantity is never materialized as measured zero.
		return {
			"ok": true,
			"errors": [],
			"availability": {"status": status},
			"scope": "a1_unit_conversion_only"
		}
	if availability.size() != 2 or not availability.has("quantity"):
		return _failure("A1_UNIT_AVAILABILITY_INVALID")
	var numeric: Dictionary = convert_quantity(availability["quantity"], target_unit_id, required)
	if not numeric["ok"]:
		return numeric
	return {
		"ok": true,
		"errors": [],
		"availability": {"status": "present", "quantity": numeric["quantity"]},
		"scope": "a1_unit_conversion_only"
	}


static func _convert_scalar(original: float, from_id: String, to_id: String) -> Dictionary:
	var canonical: float = original * float(UNIT_DEFS[from_id]["scale"])
	if from_id == "degC":
		canonical = original + 273.15
	if not is_finite(canonical):
		return {"ok": false, "error": "A1_UNIT_NUMERIC_RANGE"}
	if UNIT_DEFS[from_id]["dimension"] == "temperature" and canonical < 0.0:
		return {"ok": false, "error": "A1_UNIT_ABSOLUTE_TEMPERATURE_INVALID"}
	var converted: float = canonical / float(UNIT_DEFS[to_id]["scale"])
	if to_id == "degC":
		converted = canonical - 273.15
	if not is_finite(converted) or (original != 0.0 and converted == 0.0):
		return {"ok": false, "error": "A1_UNIT_NUMERIC_RANGE"}
	return {"ok": true, "value": converted}


static func _convert_linear(original: float, from_id: String, to_id: String) -> Dictionary:
	if UNIT_DEFS[from_id]["dimension"] == "temperature":
		return {"ok": false, "error": "A1_UNIT_TEMPERATURE_UNCERTAINTY_UNSUPPORTED"}
	var canonical: float = original * float(UNIT_DEFS[from_id]["scale"])
	var converted: float = canonical / float(UNIT_DEFS[to_id]["scale"])
	if not is_finite(canonical) or not is_finite(converted) or (original != 0.0 and converted == 0.0):
		return {"ok": false, "error": "A1_UNIT_NUMERIC_RANGE"}
	return {"ok": true, "value": converted}


static func _nonempty(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))


static func _failed(errors: Array[String]) -> Dictionary:
	return {"ok": false, "errors": errors, "scope": "a1_unit_conversion_only"}


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "errors": [code], "scope": "a1_unit_conversion_only"}


static func _flag(errors: Array[String], code: String) -> void:
	if not errors.has(code):
		errors.append(code)
