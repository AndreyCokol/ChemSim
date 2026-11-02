extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	var main = MainScript.new()
	root.add_child(main)
	assert(main.visual_field != null, "The main workspace must build its visual field")
	assert(main.status_label != null, "The main workspace must build its status label")

	main.components = [{
		"id": 7,
		"name": "Вода",
		"formula": "H2O",
		"amount": "1",
		"unit": "моль",
		"phase": "Жидкость",
		"position": Vector2(0.5, 0.5)
	}]
	main.visual_field.set_marker(7, "Вода", Vector2(0.5, 0.5))
	main.draft_dirty = false

	assert(main.visual_field.move_marker_by(7, Vector2.RIGHT, 0.1), "The real workspace marker should move")
	assert(main.draft_dirty, "The main workspace signal connection must mark the draft dirty")
	assert(Vector2(main.components[0].position).is_equal_approx(Vector2(0.6, 0.5)), "The real main draft model must receive the marker position")

	main.draft_dirty = false
	main.visual_field.marker_moved.emit(999, Vector2(0.2, 0.2))
	assert(not main.draft_dirty, "An unknown marker must not dirty the draft")

	main.queue_free()
	print("Main draft-state integration tests passed")
	quit(0)
