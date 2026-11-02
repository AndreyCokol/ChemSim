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
	main.amount_unit.add_item("custom unit")
	main.amount_unit.select(main.amount_unit.get_item_count() - 1)
	main.phase_input.add_item("custom phase")
	main.phase_input.select(main.phase_input.get_item_count() - 1)
	main._confirm_add_component()
	assert(main.components.size() == 1, "Adding a component should append one draft record")
	var added_id := int(main.components[0].id)
	assert(added_id == 1, "A new experiment should assign its first component ID")
	assert(main.selected_component_id == added_id, "The newly added component should become selected")

	main._open_edit_dialog(added_id)
	main.name_input.text = "Переименованная вода"
	main.formula_input.text = "H2O"
	main.amount_input.text = "2"
	assert(main.amount_unit.get_item_text(main.amount_unit.get_selected()) == "custom unit", "Editing should preserve unknown loaded units")
	assert(main.phase_input.get_item_text(main.phase_input.get_selected()) == "custom phase", "Editing should preserve unknown loaded phases")
	main._confirm_add_component()
	assert(main.components[0].name == "Переименованная вода", "Editing should update the existing component rather than append")
	assert(main.components.size() == 1, "Editing must not create a duplicate component")
	assert(main.components[0].unit == "custom unit" and main.components[0].phase == "custom phase", "Editing other fields must not discard custom unit or phase values")

	main._on_field_pressed(Vector2(0.3, 0.4))
	assert(Vector2(main.components[0].position).is_equal_approx(Vector2(0.3, 0.4)), "Placement should update normalized draft coordinates")
	assert(main.visual_field.markers.size() == 1 and int(main.visual_field.markers[0].id) == added_id, "Placement should create a corresponding visual marker")

	main.reaction_input.text = "raw reaction text"
	main.pressure_input.text = "raw pressure"
	main.volume_input.text = "raw volume"
	var round_trip_path := "user://experiments/main-ui-roundtrip.chemsim.json"
	main._save_draft_to_path(round_trip_path)
	assert(not main.draft_dirty, "A successful UI save should clear the dirty state")
	main.experiment_name_input.text = "Unsaved title"
	assert(main.draft_dirty, "Changing the title should mark the UI draft dirty")
	main._request_load_draft(round_trip_path)
	assert(main.discard_dialog.visible, "Opening another draft should request confirmation when the current draft is dirty")
	main.discard_dialog.confirmed.emit()
	assert(main.experiment_name == "Новый эксперимент", "Loading should restore the saved experiment title")
	assert(not main.draft_dirty, "A successful UI load should clear the dirty state")
	assert(main.components[0].name == "Переименованная вода", "Loading should restore edited component data")
	assert(main.visual_field.markers.size() == 1, "Loading should rebuild only placed visual markers")
	assert(main.reaction_input.text == "raw reaction text", "Loading should restore raw reaction text")
	assert(main.pressure_input.text == "raw pressure" and main.volume_input.text == "raw volume", "Loading should restore raw condition text")
	assert(main.components[0].unit == "custom unit" and main.components[0].phase == "custom phase", "Custom component metadata should survive save/load")
	assert(main.temperature_input.text == "298.15", "The isothermal temperature must remain fixed in the UI")

	main._remove_component(added_id)
	assert(main.components.is_empty(), "Removing a component should delete its draft record")
	assert(main.visual_field.markers.is_empty(), "Removing a component should remove its marker")
	assert(main.draft_dirty, "Removing a component should mark the draft dirty")

	main._request_new_experiment()
	assert(main.discard_dialog.visible, "New experiment should request confirmation when the draft is dirty")
	main.discard_dialog.confirmed.emit()
	assert(main.components.is_empty(), "Confirming discard should create an empty experiment")
	assert(not main.draft_dirty, "A new empty experiment should start clean")
	assert(main.reaction_input.text.is_empty() and main.pressure_input.text.is_empty() and main.volume_input.text.is_empty(), "A new experiment should clear raw reaction and condition fields")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(round_trip_path))

	main.queue_free()
	print("Main draft-state integration tests passed")
	quit(0)
