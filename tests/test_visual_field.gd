extends SceneTree

const VisualFieldScript = preload("res://scripts/visual_field.gd")

func _initialize() -> void:
	var field = VisualFieldScript.new()
	root.add_child(field)
	field.size = Vector2(100, 100)
	field.set_marker(7, "Вода", Vector2(0.5, 0.5))
	assert(field.markers.size() == 1, "A visual marker should be added")
	field.select_marker(7)
	assert(field.selected_marker_id == 7, "Selecting a component for placement should select its visual marker")
	assert(field.move_marker_by(7, Vector2.RIGHT, 0.01), "A selected marker should move by keyboard step")
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.51, 0.5)), "Keyboard movement should update normalized coordinates")
	assert(field.move_marker_by(7, Vector2.DOWN, 0.05), "A larger keyboard step should be supported")
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.51, 0.55)), "Shift-sized movement should use the requested step")
	field.select_marker(7)
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = Vector2(97.0, 95.0)
	field._gui_input(mouse_down)
	assert(field.dragging_marker_id == 7, "Clicking a marker through the input handler should begin dragging it")
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = Vector2(75.0, 65.0)
	field._gui_input(mouse_move)
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.75, 0.65)), "Mouse dragging should update the marker position")
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = Vector2(75.0, 65.0)
	field._gui_input(mouse_up)
	assert(field.dragging_marker_id == -1, "Releasing the mouse should stop marker dragging")
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	arrow.shift_pressed = true
	field._gui_input(arrow)
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.8, 0.65)), "Shift+arrow input should move the selected marker by the larger step")
	field.select_marker(999)
	assert(field.selected_marker_id == 999, "Selection API should preserve the requested id for the caller")
	field.select_marker(7)
	field.set_marker(8, "Кислород", Vector2(0.97, 0.95))
	assert(field._find_marker_at(Vector2(97.0, 95.0)) == 8, "Overlapping marker hit-testing must select the visually topmost marker")
	field.remove_marker(8)
	field.set_marker(7, "Вода", Vector2(0.97, 0.95))
	assert(not field.move_marker_by(7, Vector2.RIGHT, 0.01), "Movement past the visual boundary should be ignored")
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.97, 0.95)), "Marker coordinates must remain clamped")
	field.remove_marker(7)
	assert(field.markers.is_empty(), "Removing a marker should clear it from the visual field")
	print("Visual field tests passed")
	quit(0)
