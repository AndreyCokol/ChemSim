extends Control
class_name ChemSimGraphSeriesView

# A5 presentation only. A result producer/adapter must supply an explicit
# contract version and genuine model samples; this widget never solves chemistry.
const CONTRACT_VERSION := "0.1"
const MAX_SAMPLES := 10000
const BACKGROUND := Color("#101923")
const GRID := Color("#263746")
const TEXT := Color("#91A4B5")
const LINE := Color("#62B6A5")
const GAP := Color("#D8A85B")
const ERROR := Color("#D97878")
const ALLOWED_UNITS := {
	"concentration": ["mol/m3", "mol/L"],
	"rate": ["mol/(m3*s)"],
	"temperature": ["K", "degC"]
}

var active_quantity: String = "concentration"
# A visual graph group belongs to exactly one calculation result revision.
# Never mix a new solver run's rate with an older run's concentration series.
var active_result_ref: Dictionary = {}
var series_by_quantity: Dictionary = {}
var error_by_quantity: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(280, 112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_active_quantity(quantity: String) -> void:
	if not ALLOWED_UNITS.has(quantity):
		return
	active_quantity = quantity
	queue_redraw()

func clear_series() -> void:
	active_result_ref.clear()
	series_by_quantity.clear()
	error_by_quantity.clear()
	queue_redraw()

func submit_series(series: Dictionary, contract_version: String) -> Dictionary:
	var quantity_key: String = str(series.get("quantity_key", ""))
	var result := validate_series(series, contract_version)
	if not bool(result.get("ok", false)):
		# Fail closed even for an unknown quantity: otherwise the other tabs
		# could display old simulation values after a rejected newer payload.
		clear_series()
		var target: String = quantity_key if ALLOWED_UNITS.has(quantity_key) else active_quantity
		error_by_quantity[target] = str(result.get("error", "Неверный временной ряд"))
		queue_redraw()
		return result
	var incoming_ref: Dictionary = result.result_ref
	if not active_result_ref.is_empty() and (
		str(active_result_ref.id) != str(incoming_ref.id)
		or int(active_result_ref.record_revision) != int(incoming_ref.record_revision)
	):
		# A new calculation revision supersedes *all* old graph quantities.
		# Same-result concentration/rate/temperature may still coexist.
		clear_series()
	active_result_ref = incoming_ref.duplicate(true)
	series_by_quantity[quantity_key] = result
	error_by_quantity.erase(quantity_key)
	queue_redraw()
	return {"ok": true, "quantity_key": quantity_key, "valid_points": result.valid_points, "gaps": result.gaps}

static func validate_series(series: Dictionary, contract_version: String) -> Dictionary:
	if contract_version != CONTRACT_VERSION:
		return _fail("Неподдерживаемая версия контракта графика.")
	var quantity: Variant = series.get("quantity_key")
	if typeof(quantity) != TYPE_STRING or not ALLOWED_UNITS.has(quantity):
		return _fail("Неизвестная физическая величина графика.")
	var unit: Variant = series.get("unit_id")
	if typeof(unit) != TYPE_STRING or not ALLOWED_UNITS[quantity].has(unit):
		return _fail("Единица графика не подходит выбранной физической величине.")
	var series_id: Variant = series.get("series_id")
	if typeof(series_id) != TYPE_STRING or str(series_id).strip_edges().is_empty():
		return _fail("Отсутствует идентификатор временного ряда.")
	var result_ref: Variant = series.get("result_ref")
	if not _is_ref(result_ref):
		return _fail("Отсутствует версия или идентификатор результата.")
	if series.has("species_ref") and not _is_ref(series.species_ref):
		return _fail("Недопустимая ссылка на компонент графика.")
	var samples: Variant = series.get("samples")
	if not samples is Array:
		return _fail("Временной ряд должен содержать массив samples.")
	if samples.size() > MAX_SAMPLES:
		return _fail("Превышен допустимый объём отображаемого ряда.")
	var segments: Array = []
	var segment: Array = []
	var valid_count := 0
	var gap_count := 0
	var has_previous := false
	var previous_time := 0.0
	var min_time := INF
	var max_time := -INF
	var min_value := INF
	var max_value := -INF
	for sample in samples:
		if not sample is Dictionary:
			return _fail("Точка ряда должна быть объектом.")
		if not sample.has("time_s") or not _is_finite_number(sample.time_s):
			return _fail("Временная отметка отсутствует или не является конечным числом.")
		var time_s := float(sample.time_s)
		if has_previous and time_s <= previous_time:
			return _fail("Временные отметки должны строго возрастать.")
		has_previous = true
		previous_time = time_s
		var status: Variant = sample.get("value_status")
		if typeof(status) != TYPE_STRING or not ["valid", "missing", "invalid", "out_of_domain"].has(status):
			return _fail("Неизвестный статус точки временного ряда.")
		if status == "valid":
			if not sample.has("value") or not _is_finite_number(sample.value):
				return _fail("Валидная точка должна содержать конечное значение.")
			var value := float(sample.value)
			segment.append({"time_s": time_s, "value": value})
			min_time = minf(min_time, time_s)
			max_time = maxf(max_time, time_s)
			min_value = minf(min_value, value)
			max_value = maxf(max_value, value)
			valid_count += 1
		else:
			# Unknown, invalid and out-of-domain must never become zero or a
			# bridge connecting the surrounding valid sample segments.
			if sample.has("value"):
				return _fail("Недоступная точка не должна содержать числовое значение.")
			if not segment.is_empty():
				segments.append(segment)
				segment = []
			gap_count += 1
	if not segment.is_empty():
		segments.append(segment)
	if valid_count > 0 and (not is_finite(max_time - min_time) or not is_finite(max_value - min_value)):
		return _fail("Диапазон значений слишком широк для корректного отображения.")
	return {
		"ok": true,
		"quantity_key": quantity,
		"unit_id": unit,
		"series_id": series_id,
		"result_ref": result_ref.duplicate(true),
		"segments": segments,
		"valid_points": valid_count,
		"gaps": gap_count,
		"min_time": min_time if valid_count > 0 else 0.0,
		"max_time": max_time if valid_count > 0 else 0.0,
		"min_value": min_value if valid_count > 0 else 0.0,
		"max_value": max_value if valid_count > 0 else 0.0
	}

static func _is_ref(ref: Variant) -> bool:
	if not ref is Dictionary:
		return false
	return typeof(ref.get("id")) == TYPE_STRING and not str(ref.id).strip_edges().is_empty() and typeof(ref.get("record_revision")) == TYPE_INT and int(ref.record_revision) > 0

static func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	if size.x < 100.0 or size.y < 60.0:
		return
	if error_by_quantity.has(active_quantity):
		_draw_note("Ряд отклонён: " + str(error_by_quantity[active_quantity]), ERROR)
		return
	if not series_by_quantity.has(active_quantity):
		_draw_note("Нет расчётных временных рядов", TEXT)
		return
	var series: Dictionary = series_by_quantity[active_quantity]
	if int(series.valid_points) == 0:
		_draw_note("Нет валидных точек для отображения", GAP)
		return
	var origin := Vector2(48, size.y - 32)
	var extent := Vector2(maxf(size.x - 64.0, 1.0), maxf(size.y - 48.0, 1.0))
	draw_line(Vector2(origin.x, 8), origin, GRID, 1.0)
	draw_line(origin, origin + Vector2(extent.x, 0), GRID, 1.0)
	var min_time: float = series.min_time
	var max_time: float = series.max_time
	var min_value: float = series.min_value
	var max_value: float = series.max_value
	var time_span: float = max_time - min_time
	var value_span: float = max_value - min_value
	for segment in series.segments:
		var previous := Vector2.ZERO
		var has_previous_point := false
		for value in segment:
			var rx: float = (float(value.time_s) - min_time) / time_span if time_span > 0.0 else 0.5
			var ry: float = (float(value.value) - min_value) / value_span if value_span > 0.0 else 0.5
			var point := Vector2(origin.x + rx * extent.x, origin.y - ry * extent.y)
			if has_previous_point:
				draw_line(previous, point, LINE, 2.0, true)
			draw_circle(point, 2.5, LINE)
			previous = point
			has_previous_point = true
	draw_string(ThemeDB.fallback_font, Vector2(8, 15), str(series.unit_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(maxf(size.x - 88.0, 10.0), size.y - 10.0), "t · s", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
	if int(series.gaps) > 0:
		draw_string(ThemeDB.fallback_font, Vector2(64, 15), "Пропуски: " + str(series.gaps), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GAP)

func _draw_note(message: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(14, maxf(size.y * 0.5, 14.0)), message, HORIZONTAL_ALIGNMENT_LEFT, int(maxf(size.x - 28.0, 1.0)), 12, color)
