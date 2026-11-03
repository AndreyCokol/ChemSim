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

	# Releasing outside the Control must terminate the drag globally; a later
	# pointer re-entry must not continue moving the marker.
	var outside_down := InputEventMouseButton.new()
	outside_down.button_index = MOUSE_BUTTON_LEFT
	outside_down.pressed = true
	outside_down.position = Vector2(80.0, 65.0)
	field._gui_input(outside_down)
	assert(field.dragging_marker_id == 7, "Pressing a marker should begin a second drag")
	var outside_release := InputEventMouseButton.new()
	outside_release.button_index = MOUSE_BUTTON_LEFT
	outside_release.pressed = false
	outside_release.position = Vector2(-10.0, -10.0)
	field._input(outside_release)
	assert(field.dragging_marker_id == -1, "A global left-button release should stop dragging outside the field")
	var position_after_outside_release: Vector2 = field.markers[0].position
	var reentry_motion := InputEventMouseMotion.new()
	reentry_motion.position = Vector2(50.0, 50.0)
	field._gui_input(reentry_motion)
	assert(Vector2(field.markers[0].position).is_equal_approx(position_after_outside_release), "Pointer re-entry after outside release must not resume dragging")
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	arrow.shift_pressed = true
	field._gui_input(arrow)
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.8, 0.65)), "Shift+arrow input should move the selected marker by the larger step")
	field.set_marker(8, "Кислород", Vector2(0.97, 0.95))
	assert(field._find_marker_at(Vector2(97.0, 95.0)) == 8, "Overlapping marker hit-testing must select the visually topmost marker")
	field.remove_marker(8)
	field.set_marker(7, "Вода", Vector2(0.97, 0.95))
	assert(not field.move_marker_by(7, Vector2.RIGHT, 0.01), "Movement past the visual boundary should be ignored")
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.97, 0.95)), "Marker coordinates must remain clamped")
	field.remove_marker(7)
	assert(field.markers.is_empty(), "Removing a marker should clear it from the visual field")

	# If a component is deleted while its marker is actively being dragged,
	# later mouse motion must not resurrect an orphan marker in the view.
	field.set_marker(9, "Удаляемый", Vector2(0.5, 0.5))
	var deletion_mouse_down := InputEventMouseButton.new()
	deletion_mouse_down.button_index = MOUSE_BUTTON_LEFT
	deletion_mouse_down.pressed = true
	deletion_mouse_down.position = Vector2(50, 50)
	field._gui_input(deletion_mouse_down)
	assert(field.dragging_marker_id == 9, "Pressing a marker should begin a drag before deletion")
	field.remove_marker(9)
	assert(field.dragging_marker_id == -1, "Removing the dragged marker must end the drag")
	assert(field.selected_marker_id == -1, "Removing the dragged marker must clear selection")
	var motion_after_deletion := InputEventMouseMotion.new()
	motion_after_deletion.position = Vector2(60, 60)
	field._gui_input(motion_after_deletion)
	assert(field.markers.is_empty(), "Mouse motion after deletion must not recreate the marker")
	assert(not field.move_marker_by(9, Vector2.RIGHT, 0.01), "Deleted markers must not remain keyboard-movable")
	print("Visual field tests passed")
	quit(0)
