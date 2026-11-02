extends SceneTree

const MainScript = preload("res://scripts/main.gd")
const VisualFieldScript = preload("res://scripts/visual_field.gd")

func _initialize() -> void:
	var main = MainScript.new()
	main.components = [{
		"id": 7,
		"name": "Вода",
		"formula": "H2O",
		"amount": "1",
		"unit": "моль",
		"phase": "Жидкость",
		"position": Vector2(0.5, 0.5)
	}]
	main.draft_dirty = false

	var field = VisualFieldScript.new()
	field.set_marker(7, "Вода", Vector2(0.5, 0.5))
	field.marker_moved.connect(main._on_marker_moved)

	assert(field.move_marker_by(7, Vector2.RIGHT, 0.1), "The visual field should emit marker_moved after keyboard movement")
	assert(main.draft_dirty, "Moving a marker must mark the UI draft dirty")
	assert(Vector2(main.components[0].position).is_equal_approx(Vector2(0.6, 0.5)), "The main draft model must receive the new marker position")

	main.draft_dirty = false
	main._on_marker_moved(999, Vector2(0.2, 0.2))
	assert(not main.draft_dirty, "An unknown marker must not dirty or mutate the draft")

	print("Main draft-state integration tests passed")
	quit(0)
