extends Control
class_name ChemSimVisualField

signal field_pressed(normalized_position: Vector2)
signal marker_pressed(component_id: int)
signal marker_moved(component_id: int, normalized_position: Vector2)

const GRID_STEP := 32
const BACKGROUND := Color("#101923")
const GRID_COLOR := Color("#263746")
const TEXT_COLOR := Color("#8FA3B5")
const MARKER_COLOR := Color("#62B6A5")
const SELECTED_COLOR := Color("#D8A85B")

var markers: Array[Dictionary] = []
var selected_marker_id: int = -1
var dragging_marker_id: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(480, 320)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Визуальная раскладка: мышь для перетаскивания, стрелки для перемещения, Shift + стрелка — крупный шаг. Не влияет на химию."
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	queue_redraw()

func set_marker(component_id: int, label: String, normalized_position: Vector2) -> void:
	for index in range(markers.size()):
		if int(markers[index].id) == component_id:
			markers[index].label = label
			markers[index].position = _clamp_position(normalized_position)
			queue_redraw()
			return
	markers.append({
		"id": component_id,
		"label": label,
		"position": _clamp_position(normalized_position)
	})
	queue_redraw()

func select_marker(component_id: int) -> void:
	selected_marker_id = component_id
	queue_redraw()

func remove_marker(component_id: int) -> void:
	for index in range(markers.size() - 1, -1, -1):
		if int(markers[index].id) == component_id:
			markers.remove_at(index)
	if selected_marker_id == component_id:
		selected_marker_id = -1
	queue_redraw()

func clear_markers() -> void:
	markers.clear()
	selected_marker_id = -1
	dragging_marker_id = -1
	queue_redraw()

func _clamp_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 0.03, 0.97), clampf(value.y, 0.05, 0.95))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP
	if markers.is_empty():
		var center := size * 0.5
		draw_circle(center, 4.0, Color("#607D91"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-105, 28), "Поле эксперимента пока пусто", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_COLOR)
		_draw_focus_ring()
		return
	for marker in markers:
		var position: Vector2 = Vector2(marker.position) * size
		var component_id := int(marker.id)
		var color := SELECTED_COLOR if component_id == selected_marker_id else MARKER_COLOR
		draw_circle(position, 13.0, Color(color, 0.16))
		draw_arc(position, 13.0, 0.0, TAU, 32, color, 2.0)
		draw_circle(position, 4.0, color)
		draw_string(ThemeDB.fallback_font, position + Vector2(18, 4), str(marker.label), HORIZONTAL_ALIGNMENT_LEFT, 180, 12, TEXT_COLOR)
	_draw_focus_ring()

func _draw_focus_ring() -> void:
	if has_focus() and size.x > 2.0 and size.y > 2.0:
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), SELECTED_COLOR, false, 2.0)

func _input(event: InputEvent) -> void:
	# A drag may end outside this Control, where _gui_input will not receive
	# the release. Observe the global release so a later re-entry cannot resume it.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging_marker_id = -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_inside_tree():
				grab_focus()
			var hit_id := _find_marker_at(event.position)
			if hit_id >= 0:
				selected_marker_id = hit_id
				dragging_marker_id = hit_id
				marker_pressed.emit(hit_id)
				queue_redraw()
			else:
				field_pressed.emit(_to_normalized(event.position))
		else:
			dragging_marker_id = -1
	elif event is InputEventMouseMotion and dragging_marker_id >= 0:
		set_marker(dragging_marker_id, _marker_label(dragging_marker_id), _to_normalized(event.position))
		marker_moved.emit(dragging_marker_id, _to_normalized(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		var direction := Vector2.ZERO
		match event.keycode:
			KEY_LEFT:
				direction = Vector2.LEFT
			KEY_RIGHT:
				direction = Vector2.RIGHT
			KEY_UP:
				direction = Vector2.UP
			KEY_DOWN:
				direction = Vector2.DOWN
		if direction != Vector2.ZERO and selected_marker_id >= 0:
			var step := 0.05 if event.shift_pressed else 0.01
			if move_marker_by(selected_marker_id, direction, step):
				accept_event()

func move_marker_by(component_id: int, direction: Vector2, step: float = 0.01) -> bool:
	if direction == Vector2.ZERO or step <= 0.0:
		return false
	for marker in markers:
		if int(marker.id) != component_id:
			continue
		var next_position := _clamp_position(Vector2(marker.position) + direction.normalized() * step)
		if next_position.is_equal_approx(Vector2(marker.position)):
			return false
		set_marker(component_id, str(marker.label), next_position)
		marker_moved.emit(component_id, next_position)
		return true
	return false

func _find_marker_at(point: Vector2) -> int:
	# Later markers are drawn on top, so hit-test in reverse draw order too.
	for index in range(markers.size() - 1, -1, -1):
		var marker: Dictionary = markers[index]
		var marker_position: Vector2 = Vector2(marker.position) * size
		if marker_position.distance_to(point) <= 17.0:
			return int(marker.id)
	return -1

func _marker_label(component_id: int) -> String:
	for marker in markers:
		if int(marker.id) == component_id:
			return str(marker.label)
	return "?"

func _to_normalized(point: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return _clamp_position(Vector2(point.x / size.x, point.y / size.y))
