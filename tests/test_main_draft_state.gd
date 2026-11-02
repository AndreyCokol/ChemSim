extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	var main = MainScript.new()
	root.add_child(main)
	assert(main.visual_field != null, "The main workspace must build its visual field")
	assert(main.status_label != null, "The main workspace must build its status label")
	main.graph_buttons["rate"].pressed.emit()
	assert(main.active_graph == "rate", "Selecting a graph tab should update the active graph mode")
	assert(main.graph_title.text == "СКОРОСТЬ · ВРЕМЯ", "Selecting a graph tab should update its title")

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
	main.components.clear()
	main.visual_field.clear_markers()
	main.next_component_id = 1
	main.selected_component_id = -1

	# Exercise component CRUD and visual-marker synchronization through the
	# real main workspace methods and controls.
	main.name_input.text = "Вода"
	main.formula_input.text = "H2O"
	main.amount_input.text = "1"
	main._confirm_add_component()
	assert(main.components.size() == 2, "Adding a component should append one draft record")
	var added_id := int(main.components[1].id)
	assert(added_id == 1, "A new experiment should assign its first component ID")
	assert(main.selected_component_id == added_id, "The newly added component should become selected")

	main._open_edit_dialog(added_id)
	main.name_input.text = "Переименованная вода"
	main.formula_input.text = "H2O"
	main.amount_input.text = "2"
	main._confirm_add_component()
	assert(main.components[1].name == "Переименованная вода", "Editing should update the existing component rather than append")
	assert(main.components.size() == 2, "Editing must not create a duplicate component")

	main._on_field_pressed(Vector2(0.3, 0.4))
	assert(Vector2(main.components[1].position).is_equal_approx(Vector2(0.3, 0.4)), "Placement should update normalized draft coordinates")
	assert(main.visual_field.markers.size() == 1 and int(main.visual_field.markers[0].id) == added_id, "Placement should create a corresponding visual marker")

	var round_trip_path := "user://experiments/main-ui-roundtrip.chemsim.json"
	main._save_draft_to_path(round_trip_path)
	assert(not main.draft_dirty, "A successful UI save should clear the dirty state")
	main.experiment_name_input.text = "Unsaved title"
	assert(main.draft_dirty, "Changing the title should mark the UI draft dirty")
	main._load_draft_from_path(round_trip_path)
	assert(main.experiment_name == "Новый эксперимент", "Loading should restore the saved experiment title")
	assert(not main.draft_dirty, "A successful UI load should clear the dirty state")
	assert(main.components[1].name == "Переименованная вода", "Loading should restore edited component data")
	assert(main.visual_field.markers.size() == 1, "Loading should rebuild only placed visual markers")

	main._remove_component(added_id)
	assert(main.components.size() == 1, "Removing a component should delete its draft record")
	assert(main.visual_field.markers.is_empty(), "Removing a component should remove its marker")
	assert(main.draft_dirty, "Removing a component should mark the draft dirty")

	main._request_new_experiment()
	assert(main.discard_dialog.visible, "New experiment should request confirmation when the draft is dirty")
	main.discard_dialog.confirmed.emit()
	assert(main.components.is_empty(), "Confirming discard should create an empty experiment")
	assert(not main.draft_dirty, "A new empty experiment should start clean")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(round_trip_path))

	main.queue_free()
	print("Main draft-state integration tests passed")
	quit(0)
