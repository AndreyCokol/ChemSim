extends RefCounted
class_name ChemSimSmokeContract

# Integration-only synthetic engineering fixture. NOT measured NO2/N2O4
# kinetics, thermodynamic K, an A1 reference property or a general solver API.
const EquationParser = preload("res://src/chemistry/a2/chem_equation_parser.gd")
const CONTRACT_VERSION := "0.1"
const EQUATION := "N2O4(g) -> 2NO2(g)"
const A_ID := "demo:N2O4:g"
const B_ID := "demo:NO2:g"
const DEMO_K_PER_SECOND := 0.1
const DEMO_T_K := 298.15
const DEMO_VOLUME_M3 := 1.0
const DEMO_AMOUNT_MOL := 1.0
const DEMO_END_S := 5.0
const DEMO_SAMPLE_S := 0.25
const MAX_SAMPLES := 1024

static func _ref(id: String) -> Dictionary:
	return {"id": id, "record_revision": 1}

static func _quantity(value: float, unit: String) -> Dictionary:
	return {"value": value, "unit_id": unit}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	# RFC 4122 v4. Do not use parse offsets, UI labels or timestamps as IDs.
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var s := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [s.substr(0, 8), s.substr(8, 4), s.substr(12, 4), s.substr(16, 4), s.substr(20, 12)]

static func build_demo_request() -> Dictionary:
	var parser = EquationParser.new()
	var parsed: Dictionary = parser.parse_reaction(EQUATION)
	if not bool(parsed.get("ok", false)):
		return _fail("A2 не смог разобрать учебное уравнение.")
	var reaction: Dictionary = parsed.reaction
	if str(reaction.arrow_type) != "FORWARD" or reaction.reactants.size() != 1 or reaction.products.size() != 1:
		return _fail("Учебная модель не соответствует поддерживаемой необратимой реакции.")
	var reactant: Dictionary = reaction.reactants[0]
	var product: Dictionary = reaction.products[0]
	if str(reactant.species.phase) != "GAS" or str(product.species.phase) != "GAS":
		return _fail("A2 не подтвердил газовую фазу участников.")
	var ast_a: Dictionary = reactant.species.formula_ast
	var ast_b: Dictionary = product.species.formula_ast
	if ast_a.element_counts != {"N": 2, "O": 4} or ast_b.element_counts != {"N": 1, "O": 2}:
		return _fail("A2 вернул неожиданную формулу учебных участников.")
	if int(ast_a.net_charge) != 0 or int(ast_b.net_charge) != 0:
		return _fail("В учебном сценарии ожидаются нейтральные частицы.")
	if int(reactant.stoichiometric_coefficient) != 1 or int(product.stoichiometric_coefficient) != 2:
		return _fail("Уравнение учебного сценария не сбалансировано.")
	var balance: Dictionary = parser.check_balance(reaction)
	if not bool(balance.get("ok", false)) or not bool(balance.get("balanced", false)):
		return _fail("A2 отклонил атомный или зарядовый баланс.")
	var a := _ref(A_ID)
	var b := _ref(B_ID)
	# k and kinetic order are explicit *synthetic test parameters*, never
	# inferred from reaction coefficients or from equilibrium constants.
	var request := {
		"contract_version": CONTRACT_VERSION,
		"message_id": _uuid(),
		"kind": "simulation_request",
		"errors": [],
		"payload": {
			"model_kind": "closed_isothermal_irreversible",
			"data_quality": "hypothetical",
			"species": [
				{"species_ref": a, "initial_amount": _quantity(DEMO_AMOUNT_MOL, "mol")},
				{"species_ref": b, "initial_amount": _quantity(0.0, "mol")}
			],
			"reactions": [{
				"reaction_ref": _ref("demo:N2O4-to-NO2"),
				"arrow_type": "forward",
				"rate_law_id": "irreversible_volumetric_power_law",
				"stoichiometry": [
					{"species_ref": a, "coefficient": -int(reactant.stoichiometric_coefficient)},
					{"species_ref": b, "coefficient": int(product.stoichiometric_coefficient)}
				],
				"kinetic_orders": [{"species_ref": a, "order": 1.0}],
				"rate_constant": {
					"value": DEMO_K_PER_SECOND,
					"unit_id": "derived",
					"basis": "volumetric_power_law",
					"dimension_exponents": {"mol": 0, "m": 0, "s": -1}
				},
				"parameter_temperature": _quantity(DEMO_T_K, "K")
			}],
			"conservation_laws": [{
				"id": "demo:nitrogen-atoms",
				"coefficients": [
					{"species_ref": a, "coefficient": 2},
					{"species_ref": b, "coefficient": 1}
				]
			}],
			"volume": _quantity(DEMO_VOLUME_M3, "m3"),
			"temperature": _quantity(DEMO_T_K, "K"),
			"time_start": _quantity(0.0, "s"),
			"time_end": _quantity(DEMO_END_S, "s"),
			"output_interval": _quantity(DEMO_SAMPLE_S, "s"),
			"solver_policy": {
				"relative_tolerance": 1.0e-8,
				"absolute_tolerance": _quantity(1.0e-12, "mol"),
				"initial_step": _quantity(0.01, "s"),
				"minimum_step": _quantity(1.0e-12, "s"),
				"maximum_step": _quantity(0.25, "s"),
				"maximum_internal_steps": 10000
			}
		}
	}
	return {"ok": true, "request": request}

static func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))

static func validate_response(response: Variant, request: Dictionary) -> Dictionary:
	if not response is Dictionary:
		return _fail("Ответ A4 не является JSON-объектом.")
	if str(response.get("contract_version", "")) != CONTRACT_VERSION or str(response.get("kind", "")) != "simulation_result":
		return _fail("Неподдерживаемая версия или тип ответа A4.")
	if str(response.get("request_message_id", "")) != str(request.get("message_id", "")):
		return _fail("Ответ относится к другому запросу: графики не обновлены.")
	if typeof(response.get("message_id")) != TYPE_STRING or str(response.message_id).is_empty():
		return _fail("Отсутствует ID результата A4.")
	if not response.get("errors") is Array or not response.get("payload") is Dictionary:
		return _fail("Неверная структура ответа A4.")
	var outcome := str(response.get("outcome", ""))
	var payload: Dictionary = response.payload
	if str(payload.get("termination", "")) != outcome:
		return _fail("Исход и причина завершения расчёта противоречат друг другу.")
	var reliability: Variant = payload.get("reliability")
	if not reliability is Dictionary or str(reliability.get("data_quality", "")) != "hypothetical":
		return _fail("Невозможно подтвердить маркировку гипотетических данных.")
	var samples: Variant = payload.get("samples")
	if not samples is Array or samples.size() > MAX_SAMPLES:
		return _fail("Невалидный объём ряда A4.")
	if not ["completed", "blocked", "out_of_domain", "step_limit", "numerical_failure", "invariant_violation", "cancelled"].has(outcome):
		return _fail("Неизвестный статус A4.")
	if outcome == "blocked":
		if not samples.is_empty():
			return _fail("Заблокированный расчёт не должен возвращать точки.")
		return _fail("A4 заблокировал расчёт: " + _error_detail(response.errors))
	if not payload.get("species_ids") is Array or payload.species_ids.size() != 2:
		return _fail("Некорректные идентификаторы участников в ответе.")
	if not payload.species_ids.has(A_ID) or not payload.species_ids.has(B_ID):
		return _fail("Ответ A4 содержит другой набор участников.")
	if not _finite_number(payload.get("temperature_k")) or absf(float(payload.temperature_k) - DEMO_T_K) > 1.0e-8:
		return _fail("Температура результата A4 не соответствует запросу.")
	if not _finite_number(payload.get("requested_end_s")) or absf(float(payload.requested_end_s) - DEMO_END_S) > 1.0e-8:
		return _fail("A4 вернул другой интервал расчёта.")
	if samples.is_empty():
		return _fail("A4 не предоставил ни одной проверенной точки.")
	if outcome == "completed":
		if str(reliability.get("numerical_status", "")) != "completed" or str(reliability.get("completeness", "")) != "complete_for_declared_scope":
			return _fail("Успех A4 противоречит численному статусу или полноте.")
		if not response.errors.is_empty() or str(reliability.get("model_applicability", "")) != "not_assessed":
			return _fail("Успешный учебный расчёт не должен выдавать ошибки или неподтверждённую применимость модели.")
		var expected_count := int(roundf(DEMO_END_S / DEMO_SAMPLE_S)) + 1
		if samples.size() != expected_count:
			return _fail("Завершённый расчёт A4 должен содержать все запрошенные временные отсчёты.")
	if outcome != "completed" and str(reliability.get("completeness", "")) == "complete_for_declared_scope":
		return _fail("Частичный расчёт ошибочно отмечен полностью завершённым.")
	var concentration_samples: Array = []
	var temp_samples: Array = []
	var approved_history: Array = []
	var last_time := -1.0
	var sample_index := 0
	for sample in samples:
		if not sample is Dictionary or not _finite_number(sample.get("time_s")):
			return _fail("A4 вернул ошибочную временную точку.")
		var t := float(sample.time_s)
		if t <= last_time or t < 0.0 or t > DEMO_END_S + 1.0e-8:
			return _fail("Время результата A4 нарушает порядок или диапазон.")
		last_time = t
		if outcome == "completed" and absf(t - float(sample_index) * DEMO_SAMPLE_S) > 1.0e-7:
			return _fail("A4 вернул пропущенный или смещённый временной отсчёт при успешном расчёте.")
		var amounts: Variant = sample.get("amounts_mol")
		if not amounts is Dictionary or amounts.size() != 2:
			return _fail("A4 вернул неполный набор количеств.")
		if not amounts.has(A_ID) or not amounts.has(B_ID) or not _finite_number(amounts[A_ID]) or not _finite_number(amounts[B_ID]):
			return _fail("У результата A4 отсутствуют конечные количества.")
		var na := float(amounts[A_ID])
		var nb := float(amounts[B_ID])
		if sample_index == 0 and (absf(na - DEMO_AMOUNT_MOL) > 1.0e-8 or absf(nb) > 1.0e-8):
			return _fail("Начальное состояние A4 отличается от заявленного в запросе.")
		if na < -1.0e-9 or nb < -1.0e-9 or absf(2.0 * na + nb - 2.0) > 1.0e-5:
			return _fail("Нарушена неотрицательность или атомный баланс учебного ряда.")
		concentration_samples.append({"time_s": t, "value_status": "valid", "value": nb / DEMO_VOLUME_M3})
		temp_samples.append({"time_s": t, "value_status": "valid", "value": DEMO_T_K})
		approved_history.append({"time_s": t, "n2o4_mol": na, "no2_mol": nb})
		sample_index += 1
	if absf(float(approved_history[0].time_s)) > 1.0e-8:
		return _fail("Первый отсчёт A4 должен соответствовать t=0.")
	var last_status := str(payload.get("last_valid_time_status", ""))
	if last_status != "present" or not _finite_number(payload.get("last_valid_time_s")) or absf(float(payload.last_valid_time_s) - last_time) > 1.0e-8:
		return _fail("Последняя проверенная точка не согласуется с метаданными A4.")
	if outcome == "completed" and absf(last_time - DEMO_END_S) > 1.0e-8:
		return _fail("Завершённый результат A4 не достиг заказанного времени.")
	var rref := {"id": str(response.message_id), "record_revision": 1}
	var concentration := {
		"series_id": "demo:no2_concentration", "result_ref": rref,
		"quantity_key": "concentration", "species_ref": _ref(B_ID),
		"unit_id": "mol/m3", "samples": concentration_samples
	}
	var temperature := {
		"series_id": "demo:isothermal_constant", "result_ref": rref,
		"quantity_key": "temperature", "unit_id": "K", "samples": temp_samples
	}
	return {
		"ok": true, "completed": outcome == "completed", "outcome": outcome,
		"reliability": reliability, "history": approved_history,
		"concentration_series": concentration, "temperature_series": temperature,
		"warning": "Синтетическое k=0,1 с⁻¹; не справочные данные для N₂O₄/NO₂. " +
			("Достигнут конец интервала." if outcome == "completed" else "Получен только проверенный префикс; расчёт остановлен: " + outcome)
	}

static func _error_detail(errors: Array) -> String:
	if errors.is_empty() or not errors[0] is Dictionary:
		return "Неизвестная причина."
	var error: Dictionary = errors[0]
	var context: Variant = error.get("context")
	if context is Dictionary:
		return str(context.get("reason", "Отсутствуют обязательные параметры."))
	return str(error.get("code", "Неизвестная причина."))
