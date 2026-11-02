extends SceneTree

const VisualFieldScript = preload("res://scripts/visual_field.gd")

func _initialize() -> void:
	var field = VisualFieldScript.new()
	root.add_child(field)
	field.set_marker(7, "Вода", Vector2(0.5, 0.5))
	assert(field.markers.size() == 1, "A visual marker should be added")
	assert(field.move_marker_by(7, Vector2.RIGHT, 0.01), "A selected marker should move by keyboard step")
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.51, 0.5)), "Keyboard movement should update normalized coordinates")
	assert(field.move_marker_by(7, Vector2.DOWN, 0.05), "A larger keyboard step should be supported")
	assert(Vector2(field.markers[0].position).is_equal_approx(Vector2(0.51, 0.55)), "Shift-sized movement should use the requested step")
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
