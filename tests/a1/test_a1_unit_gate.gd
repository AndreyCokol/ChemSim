extends SceneTree

## Synthetic numerical unit fixtures only; not physical/chemical source validation.
const Gate = preload("res://src/chemistry/a1/a1_unit_gate.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_exact_registered_dimensions()
	_test_absolute_temperature_only()
	_test_unknown_and_measured_zero()
	_test_basis_and_dimension_fail_closed()
	_test_numeric_range_and_unit_aliases()
	_test_uncertainty_availability()
	if failures.is_empty():
		print("PASS: A1 strict unit dimensions, basis, Availability and uncertainty gates")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _context(dim: String, basis: String = "") -> Dictionary:
	var ctx: Dictionary = {"dimension_id": dim}
	if not basis.is_empty():
		ctx["basis"] = basis
	return ctx


func _q(value: Variant, unit_id: String, basis: String = "") -> Dictionary:
	var q: Dictionary = {"value": value, "unit_id": unit_id}
	if not basis.is_empty():
		q["basis"] = basis
	return q


func _test_exact_registered_dimensions() -> void:
	_num(Gate.convert_quantity(_q(1000.0, "g"), "kg", _context("mass")), 1.0, "1000 g -> 1 kg")
	_num(Gate.convert_quantity(_q(1.0, "kg"), "g", _context("mass")), 1000.0, "1 kg -> 1000 g")
	_num(Gate.convert_quantity(_q(2.5, "L"), "m3", _context("volume")), 0.0025, "2.5 L -> 0.0025 m3")
	_num(Gate.convert_quantity(_q(0.001, "m3"), "L", _context("volume")), 1.0, "m3 -> L")
	_num(Gate.convert_quantity(_q(1.0, "bar", "absolute_pressure"), "Pa", _context("pressure", "absolute_pressure")), 100000.0, "1 bar -> 100000 Pa")
	_num(Gate.convert_quantity(_q(250000.0, "Pa", "absolute_pressure"), "bar", _context("pressure", "absolute_pressure")), 2.5, "250000 Pa -> 2.5 bar")
	_num(Gate.convert_quantity(_q(0.1, "mol/L", "final_mixture_analytical"), "mol/m3", _context("concentration", "final_mixture_analytical")), 100.0, "final-mixture concentration -> A4 canonical unit")
	_num(Gate.convert_quantity(_q(1000.0, "mol/m3", "free_ion"), "mol/L", _context("concentration", "free_ion")), 1.0, "concentration m3 -> L")
	_num(Gate.convert_quantity(_q(3.0, "s"), "s", _context("time")), 3.0, "identity time conversion")
	_num(Gate.convert_quantity(_q(2.0, "mol"), "mol", _context("amount")), 2.0, "identity mol conversion")
	_num(Gate.convert_quantity(_q(1.0, "mol/s", "reaction_rate_amount"), "mol/s", _context("amount_rate", "reaction_rate_amount")), 1.0, "amount rate no made-up conversions")
	_num(Gate.convert_quantity(_q(1.0, "mol/(m3*s)", "volumetric_rate"), "mol/(m3*s)", _context("volumetric_rate", "volumetric_rate")), 1.0, "volumetric rate identity")
	_num(Gate.convert_quantity(_q(10.0, "J/mol", "Arrhenius_activation_energy"), "J/mol", _context("molar_energy", "Arrhenius_activation_energy")), 10.0, "molar energy label preserved")


func _test_absolute_temperature_only() -> void:
	var ctx: Dictionary = _context("temperature")
	ctx["temperature_kind"] = "absolute"
	_num(Gate.convert_quantity(_q(25.0, "degC"), "K", ctx), 298.15, "25 Celsius absolute -> Kelvin")
	_num(Gate.convert_quantity(_q(298.15, "K"), "degC", ctx), 25.0, "298.15 Kelvin absolute -> Celsius")
	_num(Gate.convert_quantity(_q(-273.15, "degC"), "K", ctx), 0.0, "absolute zero allowed in unit converter; model validity is separate")
	_code(Gate.convert_quantity(_q(-274.0, "degC"), "K", ctx), "A1_UNIT_ABSOLUTE_TEMPERATURE_INVALID", "below absolute zero rejected")
	var delta_ctx: Dictionary = _context("temperature")
	delta_ctx["temperature_kind"] = "difference"
	_code(Gate.convert_quantity(_q(25.0, "degC"), "K", delta_ctx), "A1_UNIT_TEMPERATURE_KIND_UNSUPPORTED", "Celsius differences not treated as absolute")
	_code(Gate.convert_quantity(_q(25.0, "degC"), "K", _context("temperature")), "A1_UNIT_TEMPERATURE_KIND_UNSUPPORTED", "no implicit temperature kind")
	var wrong: Dictionary = _context("pressure", "absolute_pressure")
	wrong["temperature_kind"] = "absolute"
	_code(Gate.convert_quantity(_q(2.0, "bar", "absolute_pressure"), "Pa", wrong), "A1_UNIT_TEMPERATURE_KIND_NOT_APPLICABLE", "temperature type not interpreted on pressure")


func _test_unknown_and_measured_zero() -> void:
	var ctx: Dictionary = _context("concentration", "final_mixture_analytical")
	var unknown: Dictionary = Gate.convert_availability({"status": "unknown"}, "mol/m3", ctx)
	_ok(unknown, "unknown concentration remains unspecified")
	_expect(unknown["availability"] == {"status": "unknown"}, "unknown cannot become measured zero")
	for state in ["not_reported", "not_assessed", "not_applicable", "withheld"]:
		var result: Dictionary = Gate.convert_availability({"status": state}, "mol/m3", ctx)
		_ok(result, "explicit " + state + " is preserved")
		_expect(result["availability"] == {"status": state}, "no numeric value added for " + state)
	var measured: Dictionary = Gate.convert_availability({
		"status": "present",
		"quantity": _q(0.0, "mol/L", "final_mixture_analytical")
	}, "mol/m3", ctx)
	_ok(measured, "explicit present zero must be preserved")
	_expect(measured["availability"]["status"] == "present", "present remains distinct from unknown")
	_expect(measured["availability"]["quantity"]["value"] == 0.0, "zero remains measured zero")
	_code(Gate.convert_availability({"status": "unknown"}, "mol/kg", ctx), "A1_UNIT_UNREGISTERED", "unknown is not permission to use an unregistered unit")
	_code(Gate.convert_availability({"status": "unknown"}, "mol/m3", _context("amount")), "A1_UNIT_REQUIREMENT_MISMATCH", "unknown cannot evade declared expected dimension")
	_code(Gate.convert_availability({"status": "unknown", "quantity": null}, "mol/m3", ctx), "A1_UNIT_AVAILABILITY_INVALID", "unknown cannot carry null quantity")
	_code(Gate.convert_availability({"status": "present"}, "mol/m3", ctx), "A1_UNIT_AVAILABILITY_INVALID", "present requires a quantity")
	_code(Gate.convert_availability({"status": "present", "quantity": null}, "mol/m3", ctx), "A1_UNIT_QUANTITY_INVALID", "present cannot carry null")
	_code(Gate.convert_availability({"status": "valid"}, "mol/m3", ctx), "A1_UNIT_AVAILABILITY_INVALID", "status valid is not Availability")


func _test_basis_and_dimension_fail_closed() -> void:
	_code(Gate.convert_quantity(_q(1.0, "kg"), "mol", _context("amount")), "A1_UNIT_DIMENSION_MISMATCH", "mass cannot become mole without molar mass")
	_code(Gate.convert_quantity(_q(1.0, "mol/s", "amount"), "mol/(m3*s)", _context("volumetric_rate", "amount")), "A1_UNIT_DIMENSION_MISMATCH", "rate requires volume, no implicit conversion")
	_code(Gate.convert_quantity(_q(1.0, "mol/L", "aqueous_molarity"), "mol/m3", _context("concentration", "aqueous_molality")), "A1_UNIT_BASIS_MISMATCH", "molarity cannot be molality by unit conversion")
	_code(Gate.convert_quantity(_q(1.0, "mol/L"), "mol/m3", _context("concentration")), "A1_UNIT_BASIS_MISSING", "no unscoped chemistry concentration")
	_code(Gate.convert_quantity(_q(1.0, "bar"), "Pa", _context("pressure")), "A1_UNIT_BASIS_MISSING", "absolute vs gauge cannot be assumed")
	_code(Gate.convert_quantity(_q(1.0, "1", "water_K"), "1", _context("dimensionless", "kinetic_k")), "A1_UNIT_BASIS_MISMATCH", "K vs k require semantic/model identity")
	_code(Gate.convert_quantity(_q(1.0, "1"), "1", _context("dimensionless")), "A1_UNIT_BASIS_MISSING", "no untyped K or activity ratio")
	_code(Gate.convert_quantity(_q(1.0, "g"), "kg", _context("concentration")), "A1_UNIT_REQUIREMENT_MISMATCH", "required dimension is explicit")
	_code(Gate.convert_quantity(_q(1.0, "g", "material_basis"), "kg", _context("mass")), "A1_UNIT_BASIS_MISSING", "cannot discard existing quantity basis")
	_code(Gate.convert_quantity(_q(1.0, "g"), "kg", _context("mass", "material_basis")), "A1_UNIT_BASIS_MISSING", "cannot fabricate required basis")


func _test_numeric_range_and_unit_aliases() -> void:
	_code(Gate.convert_quantity(_q(true, "g"), "kg", _context("mass")), "A1_UNIT_VALUE_INVALID", "boolean is not a number")
	_code(Gate.convert_quantity(_q("5", "g"), "kg", _context("mass")), "A1_UNIT_VALUE_INVALID", "string not a number")
	_code(Gate.convert_quantity(_q(NAN, "g"), "kg", _context("mass")), "A1_UNIT_VALUE_INVALID", "NaN not finite")
	_code(Gate.convert_quantity(_q(INF, "g"), "kg", _context("mass")), "A1_UNIT_VALUE_INVALID", "Inf not finite")
	_code(Gate.convert_quantity(_q(1.0e308, "kg"), "g", _context("mass")), "A1_UNIT_NUMERIC_RANGE", "overflow blocked")
	# Construct a positive subnormal at runtime. A very small literal may
	# already parse as 0 before the unit gate sees it.
	var tiny: float = 1.0e-300 / 1.0e22
	_expect(tiny > 0.0, "subnormal fixture remains nonzero at gate input")
	_code(Gate.convert_quantity(_q(tiny, "g"), "kg", _context("mass")), "A1_UNIT_NUMERIC_RANGE", "underflow to zero blocked")
	var same: Dictionary = Gate.convert_quantity(_q(tiny, "g"), "g", _context("mass"))
	_ok(same, "same-unit conversion retains positive subnormal")
	if same["ok"]:
		_expect(same["quantity"]["value"] == tiny, "same-unit conversion cannot round tiny input to zero")
	_code(Gate.convert_quantity(_q(1.0, "mol/kg"), "mol/L", _context("concentration", "aqueous_molality")), "A1_UNIT_UNREGISTERED", "molal unit not currently registered for direct conversion")
	_code(Gate.convert_quantity(_q(1.0, "mL"), "L", _context("volume")), "A1_UNIT_UNREGISTERED", "unregistered alias rejected")
	_code(Gate.convert_quantity(_q(1.0, "g"), "KG", _context("mass")), "A1_UNIT_UNREGISTERED", "case-sensitive registered units")
	var bad_requirement: Dictionary = _context("mass")
	bad_requirement["model_accepted"] = true
	_code(Gate.convert_quantity(_q(1.0, "g"), "kg", bad_requirement), "A1_UNIT_REQUIREMENT_FIELD_UNSUPPORTED", "unit conversion cannot accept an implicit model certification")
	var unexpected: Dictionary = _q(1.0, "g")
	unexpected["model_accepted"] = true
	_code(Gate.convert_quantity(unexpected, "kg", _context("mass")), "A1_UNIT_QUANTITY_FIELD_UNSUPPORTED", "unit helper cannot assign model eligibility")


func _test_uncertainty_availability() -> void:
	var q: Dictionary = _q(100.0, "g")
	q["uncertainty"] = {
		"status": "present",
		"quantity": _q(2.0, "g")
	}
	var res: Dictionary = Gate.convert_quantity(q, "kg", _context("mass"))
	_ok(res, "convert reported uncertainty with same scale")
	if res["ok"]:
		_expect(is_equal_approx(res["quantity"]["uncertainty"]["quantity"]["value"], 0.002), "2 g uncertainty -> 0.002 kg")
		_expect(res["quantity"]["uncertainty"]["quantity"]["unit_id"] == "kg", "uncertainty unit converted with value")
	q["uncertainty"] = {"status": "not_reported"}
	res = Gate.convert_quantity(q, "kg", _context("mass"))
	_ok(res, "unreported uncertainty kept explicit")
	if res["ok"]:
		_expect(res["quantity"]["uncertainty"] == {"status": "not_reported"}, "unreported is not zero")
	q["uncertainty"] = {"status": "present", "quantity": _q(-2.0, "g")}
	_code(Gate.convert_quantity(q, "kg", _context("mass")), "A1_UNIT_UNCERTAINTY_INVALID", "negative uncertainty invalid")
	q["uncertainty"] = {"status": "present", "quantity": _q(2.0, "kg")}
	_code(Gate.convert_quantity(q, "kg", _context("mass")), "A1_UNIT_UNCERTAINTY_INVALID", "uncertainty cannot silently differ from asserted source unit")
	q["uncertainty"] = {"status": "unknown", "quantity": _q(0.0, "g")}
	_code(Gate.convert_quantity(q, "kg", _context("mass")), "A1_UNIT_UNCERTAINTY_INVALID", "unknown cannot carry zero uncertainty")
	var absolute_ctx: Dictionary = _context("temperature")
	absolute_ctx["temperature_kind"] = "absolute"
	var degc: Dictionary = _q(25.0, "degC")
	degc["uncertainty"] = {"status": "present", "quantity": _q(0.1, "degC")}
	_code(Gate.convert_quantity(degc, "K", absolute_ctx), "A1_UNIT_TEMPERATURE_UNCERTAINTY_UNSUPPORTED", "no delta-C wire dimension for numeric temperature uncertainty")
	var con: Dictionary = _q(1.0, "mol/L", "analytical")
	con["uncertainty"] = {"status": "present", "quantity": _q(0.01, "mol/L", "free_ion")}
	_code(Gate.convert_quantity(con, "mol/m3", _context("concentration", "analytical")), "A1_UNIT_UNCERTAINTY_BASIS_MISMATCH", "uncertainty basis must match source")


func _num(result: Dictionary, expected: float, label: String) -> void:
	_ok(result, label)
	if result.get("ok", false):
		_expect(is_equal_approx(float(result["quantity"]["value"]), expected), label + " expected " + str(expected) + " got " + str(result["quantity"]["value"]))


func _ok(result: Dictionary, label: String) -> void:
	_expect(result.get("ok", false) == true, label + " expected success got " + str(result.get("errors", [])))


func _code(result: Dictionary, code: String, label: String) -> void:
	_expect(result.get("ok", true) == false and result.get("errors", []).has(code), label + " expected " + code + " got " + str(result.get("errors", [])))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
