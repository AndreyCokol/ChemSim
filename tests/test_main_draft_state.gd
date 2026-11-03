extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScript.new()
	root.add_child(main)
	await process_frame
	assert(main.visual_field != null, "The main workspace must build its visual field")
	assert(main.visual_field.focus_mode == Control.FOCUS_ALL, "The visual field must participate in keyboard focus traversal")
	var next_focus: Control = main.visual_field.find_next_valid_focus()
	var previous_focus: Control = main.visual_field.find_prev_valid_focus()
	assert(next_focus != null, "The visual field must have a forward keyboard-focus destination")
	assert(previous_focus != null, "The visual field must have a backward keyboard-focus destination")
	assert(next_focus != main.visual_field and previous_focus != main.visual_field, "Tab traversal must be able to leave the visual field in both directions")
	assert(next_focus.is_visible_in_tree() and next_focus.focus_mode != Control.FOCUS_NONE, "The next focus target must be visible and keyboard-focusable")
	# Walk the actual focus chain from the custom visual field. This catches
	# accidental dead ends, invisible destinations, and focus loops that skip
	# most of the workspace's keyboard-operable controls.
	var forward_focus_chain: Array[Control] = []
	var forward_seen := {}
	var focus_cursor: Control = main.visual_field
	for _step in range(64):
		focus_cursor = focus_cursor.find_next_valid_focus()
		if focus_cursor == null or focus_cursor == main.visual_field:
			break
		assert(not forward_seen.has(focus_cursor.get_instance_id()), "Forward focus traversal must not enter a premature loop")
		assert(focus_cursor.is_visible_in_tree(), "Forward focus traversal must not target a hidden control")
		assert(focus_cursor.focus_mode != Control.FOCUS_NONE, "Forward focus traversal must target keyboard-focusable controls")
		forward_seen[focus_cursor.get_instance_id()] = true
		forward_focus_chain.append(focus_cursor)
	assert(forward_focus_chain.size() >= 4, "The visual field should be connected to a meaningful keyboard-focus chain")

	var backward_seen := {}
	focus_cursor = main.visual_field
	for _step in range(64):
		focus_cursor = focus_cursor.find_prev_valid_focus()
		if focus_cursor == null or focus_cursor == main.visual_field:
			break
		assert(not backward_seen.has(focus_cursor.get_instance_id()), "Backward focus traversal must not enter a premature loop")
		assert(focus_cursor.is_visible_in_tree(), "Backward focus traversal must not target a hidden control")
		assert(focus_cursor.focus_mode != Control.FOCUS_NONE, "Backward focus traversal must target keyboard-focusable controls")
		backward_seen[focus_cursor.get_instance_id()] = true
	main.visual_field.grab_focus()
	assert(main.visual_field.has_focus(), "The visual field must accept keyboard focus")
	next_focus.grab_focus()
	assert(next_focus.has_focus(), "Keyboard focus must be able to leave the visual field for the next valid control")
	main.visual_field.grab_focus()
	assert(main.visual_field.has_focus(), "Keyboard focus must be able to return to the visual field")
	assert(main.status_label != null, "The main workspace must build its status label")
	assert(main.get_window().min_size == Vector2i(1120, 680), "The workspace window must enforce its minimum usable size")
	var header_scroll: ScrollContainer = main.find_child("HeaderScroll", true, false)
	var body_scroll: ScrollContainer = main.find_child("BodyScroll", true, false)
	assert(header_scroll != null and header_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "The header should remain horizontally navigable in narrow windows")
	assert(body_scroll != null and body_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "The workspace body should remain vertically navigable in short windows")
	main.graph_buttons["rate"].pressed.emit()
	assert(main.active_graph == "rate", "Selecting a graph tab should update the active graph mode")
	assert(main.graph_title.text == "СКОРОСТЬ · ВРЕМЯ", "Selecting a graph tab should update its title")
	assert(main.graph_view != null and main.graph_view.active_quantity == "rate", "Graph tabs must switch the actual presentation surface")
	assert(main.graph_view.series_by_quantity.is_empty(), "No solver values must be shown before admission")
	var synthetic_graph := {
		"series_id": "workspace-presentation-only-test",
		"result_ref": {"id": "synthetic-result", "record_revision": 1},
		"quantity_key": "rate",
		"unit_id": "mol/(m3*s)",
		"samples": [{"time_s": 0.0, "value_status": "valid", "value": 2.0}]
	}
	assert(bool(main._accept_graph_series(synthetic_graph, "0.1").get("ok", false)), "A synthetic presentation fixture with correct rate units should be accepted")
	assert(main.graph_view.series_by_quantity.has("rate"), "The admitted rate should be shown in its own graph tab")
	var same_run_concentration := synthetic_graph.duplicate(true)
	same_run_concentration["quantity_key"] = "concentration"
	same_run_concentration["unit_id"] = "mol/m3"
	assert(bool(main._accept_graph_series(same_run_concentration, "0.1").get("ok", false)), "The workspace may display multiple quantities from the same calculation")
	assert(main.graph_view.series_by_quantity.has("concentration") and main.graph_view.series_by_quantity.has("rate"), "Same-result quantities should coexist")
	var next_run_rate := synthetic_graph.duplicate(true)
	next_run_rate["result_ref"] = {"id": "second-synthetic-run", "record_revision": 1}
	assert(bool(main._accept_graph_series(next_run_rate, "0.1").get("ok", false)), "A newer result must be admitted")
	assert(not main.graph_view.series_by_quantity.has("concentration"), "A new calculation must clear older concentration results")
	assert(main.graph_view.series_by_quantity.has("rate"), "The newest calculation's rate should remain available")
	main.graph_buttons["concentration"].pressed.emit()
	assert(main.graph_view.active_quantity == "concentration", "Changing modes must update the real graph view")
	assert(not main.graph_view.series_by_quantity.has("concentration"), "Rate samples must not leak into concentration")
	main.graph_view.clear_series()
	assert(main.graph_view.series_by_quantity.is_empty(), "Clearing synthetic fixture data must restore unavailable state")
	assert(bool(main._accept_graph_series(synthetic_graph, "0.1").get("ok", false)), "Test fixture can be re-admitted after clearing")
	main._on_reaction_changed("synthetic edit")
	assert(main.graph_view.series_by_quantity.is_empty(), "Editing reaction text must invalidate all cached simulation graphs")

	var typed_components: Array[Dictionary] = [{
		"id": 7,
		"name": "Вода",
		"formula": "H2O",
		"amount": "1",
		"unit": "моль",
		"phase": "Жидкость",
		"position": Vector2(0.5, 0.5)
	}]
	main.components = typed_components
	main.visual_field.set_marker(7, "Вода", Vector2(0.5, 0.5))
	main.draft_dirty = false

	assert(bool(main._accept_graph_series(synthetic_graph, "0.1").get("ok", false)), "Rate fixture should be admitted before a presentation-only movement")
	assert(main.visual_field.move_marker_by(7, Vector2.RIGHT, 0.1), "The real workspace marker should move")
	assert(main.graph_view.series_by_quantity.has("rate"), "Presentation-only marker movement must not invalidate chemical results")
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

	# Editing a placed component must move visual selection away from
	# whichever marker was selected previously.
	main.components.append({
		"id": 2,
		"name": "Кислород",
		"formula": "O2",
		"amount": "1",
		"unit": "моль",
		"phase": "Газ",
		"position": Vector2(0.7, 0.7)
	})
	main.visual_field.set_marker(2, "Кислород", Vector2(0.7, 0.7))
	main.visual_field.select_marker(2)
	main._open_edit_dialog(added_id)
	main.name_input.text = "Переименованная вода"
	main.formula_input.text = "H2O"
	main.amount_input.text = "2"
	assert(main.amount_unit.get_item_text(main.amount_unit.get_selected()) == "custom unit", "Editing should preserve unknown loaded units")
	assert(main.phase_input.get_item_text(main.phase_input.get_selected()) == "custom phase", "Editing should preserve unknown loaded phases")
	main._confirm_add_component()
	assert(main.components[0].name == "Переименованная вода", "Editing should update the existing component rather than append")
	assert(main.components.size() == 2, "Editing must update the existing component without adding another")
	assert(main.components[0].unit == "custom unit" and main.components[0].phase == "custom phase", "Editing other fields must not discard custom unit or phase values")
	assert(main.selected_component_id == added_id, "The edited component should remain selected in the composition")
	assert(main.visual_field.selected_marker_id == added_id, "Editing a placed component should synchronize visual-marker selection")
	main._remove_component(2)
	assert(main.components.size() == 1, "Removing the temporary second component should restore the one-component fixture")

	main._select_component_for_placement(added_id)
	assert(main.visual_field.has_focus(), "Selecting a component for placement should move keyboard focus to the visual field")
	assert(main.visual_field.selected_marker_id == -1, "An unplaced component should not create a phantom visual selection")
	assert(main.visual_field.markers.is_empty(), "Selecting an unplaced component must not create a visual marker before placement")
	assert(not main.visual_field.move_marker_by(added_id, Vector2.RIGHT, 0.01), "An unplaced component must not be keyboard-movable before placement")
	main._on_field_pressed(Vector2(0.3, 0.4))
	assert(main.visual_field.selected_marker_id == added_id, "Placing a component should select its visual marker for keyboard movement")
	assert(Vector2(main.components[0].position).is_equal_approx(Vector2(0.3, 0.4)), "Placement should update normalized draft coordinates")
	assert(main.visual_field.markers.size() == 1 and int(main.visual_field.markers[0].id) == added_id, "Placement should create a corresponding visual marker")

	main.reaction_input.text = "raw reaction text"
	main.pressure_input.text = "raw pressure"
	main.volume_input.text = "raw volume"
	var round_trip_path := "user://experiments/main-ui-roundtrip.chemsim.json"
	main._save_draft_to_path(round_trip_path)
	assert(not main.draft_dirty, "A successful UI save should clear the dirty state")
	# Reopening the clean active path should load directly without a discard prompt.
	assert(bool(main._accept_graph_series(synthetic_graph, "0.1").get("ok", false)), "Fixture should be present before a clean Open")
	main._request_load_draft(round_trip_path)
	assert(main.graph_view.series_by_quantity.is_empty(), "Opening another draft must clear prior experiment graphs")
	assert(not main.discard_dialog.visible, "Opening the current path while clean should not show a discard confirmation")
	assert(not main.draft_dirty, "A clean same-path Open should leave the draft clean")
	assert(main.current_draft_path == round_trip_path, "A clean same-path Open should retain the current path")

	# Reopening the same path while dirty is destructive and must require
	# confirmation; cancellation must retain the edits and active path.
	main.experiment_name_input.text = "Unsaved same-path edit"
	main._request_load_draft(round_trip_path)
	assert(main.discard_dialog.visible, "Opening the active path while dirty must request discard confirmation")
	main.discard_dialog.canceled.emit()
	assert(main.experiment_name == "Unsaved same-path edit" and main.draft_dirty, "Cancelling a dirty same-path Open must preserve edits")
	assert(main.current_draft_path == round_trip_path, "Cancelling a dirty same-path Open must preserve the active path")
	main._request_load_draft(round_trip_path)
	main.discard_dialog.confirmed.emit()
	assert(main.experiment_name == "Новый эксперимент" and not main.draft_dirty, "Confirming a dirty same-path Open must restore the saved contents")
	assert(main.current_draft_path == round_trip_path, "Confirming a same-path Open must retain the active path")
	main.experiment_name_input.text = "Unsaved title"
	assert(main.draft_dirty, "Changing the title should mark the UI draft dirty")
	main._request_load_draft(round_trip_path)
	assert(main.discard_dialog.visible, "Opening another draft should request confirmation when the current draft is dirty")
	main.discard_dialog.canceled.emit()
	assert(main.pending_open_path.is_empty(), "Cancelling Open must clear the pending target path")
	assert(main.draft_dirty, "Cancelling the open confirmation must preserve the dirty state")
	assert(main.experiment_name == "Unsaved title", "Cancelling the open confirmation must preserve the current experiment")
	assert(main.current_draft_path == round_trip_path, "Cancelling Open must preserve the current draft path")
	main._request_load_draft(round_trip_path)
	assert(main.discard_dialog.visible, "Retrying Open should request confirmation again")
	main.discard_dialog.confirmed.emit()
	assert(main.experiment_name == "Новый эксперимент", "Loading should restore the saved experiment title")
	assert(not main.draft_dirty, "A successful UI load should clear the dirty state")
	assert(main.components[0].name == "Переименованная вода", "Loading should restore edited component data")
	assert(main.visual_field.markers.size() == 1, "Loading should rebuild only placed visual markers")
	assert(main.reaction_input.text == "raw reaction text", "Loading should restore raw reaction text")
	assert(main.pressure_input.text == "raw pressure" and main.volume_input.text == "raw volume", "Loading should restore raw condition text")
	assert(main.components[0].unit == "custom unit" and main.components[0].phase == "custom phase", "Custom component metadata should survive save/load")
	assert(main.temperature_input.text == "298.15", "The isothermal temperature must remain fixed in the UI")
	assert(main.current_draft_path == round_trip_path, "Loading a draft should remember its path for subsequent Save actions")
	main.experiment_name_input.text = "Saved again"
	assert(main.draft_dirty, "Editing a loaded draft should mark it dirty before Save")
	main._save_draft()
	assert(not main.draft_dirty, "Save should write to the current draft path and clear dirty state")
	assert(main.current_draft_path == round_trip_path, "Save should retain the current draft path")
	main.experiment_name_input.text = "Save As title"
	var save_as_path := "user://experiments/main-ui-save-as.chemsim.json"
	main._save_draft_to_path(save_as_path)
	assert(main.current_draft_path == save_as_path, "Save As should switch the current draft path after a successful write")
	assert(not main.draft_dirty, "Successful Save As should clear dirty state")

	# Both pickers should reopen in the active draft directory. Save As should
	# also prefill the current filename rather than a generic default.
	main.open_dialog.current_dir = "user://"
	main._open_draft_picker()
	assert(main.open_dialog.current_dir == save_as_path.get_base_dir(), "Open picker should restore the active draft directory")
	main.open_dialog.hide()
	main.save_dialog.current_dir = "user://"
	main.save_dialog.current_file = "wrong-name.chemsim.json"
	main._save_draft_picker()
	assert(main.save_dialog.current_dir == save_as_path.get_base_dir(), "Save As picker should restore the active draft directory")
	assert(main.save_dialog.current_file == save_as_path.get_file(), "Save As picker should prefill the active draft filename")
	main.save_dialog.hide()

	# Save As may target the current path; a successful same-path transaction
	# must retain that path and clear dirty state just like an ordinary save.
	main.experiment_name_input.text = "Save As same path"
	main._save_draft_to_path(save_as_path)
	assert(not main.draft_dirty, "Save As to the current path should clear dirty state after a successful write")
	assert(main.current_draft_path == save_as_path, "Save As to the current path must retain the selected path")

	# An empty Open selection must fail closed. It must not be confused with
	# New, and must not change the active path or clean experiment state.
	main.discard_dialog.hide()
	var clean_title_before_empty_open: String = main.experiment_name
	var clean_path_before_empty_open: String = main.current_draft_path
	var clean_count_before_empty_open: int = main.components.size()
	main._request_load_draft("")
	assert(main.io_error_dialog.visible, "Empty clean Open must show an error")
	assert(not main.discard_dialog.visible, "Empty clean Open must not request discard confirmation")
	assert(main.experiment_name == clean_title_before_empty_open, "Empty clean Open must preserve the experiment title")
	assert(main.components.size() == clean_count_before_empty_open, "Empty clean Open must preserve the component list")
	assert(main.current_draft_path == clean_path_before_empty_open and not main.draft_dirty, "Empty clean Open must preserve the active path and clean state")
	assert(main.pending_open_path.is_empty(), "Empty clean Open must not retain a pending action")
	main.io_error_dialog.hide()

	# A failed Open from a clean workspace must preserve the complete current
	# experiment and its active path, without introducing dirty state.
	var clean_title_before_failed_open: String = main.experiment_name
	var clean_component_count_before_failed_open: int = main.components.size()
	var clean_path_before_failed_open: String = main.current_draft_path
	var clean_missing_open_path := "user://experiments/does-not-exist-clean-ui-audit.chemsim.json"
	if FileAccess.file_exists(clean_missing_open_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(clean_missing_open_path))
	main._request_load_draft(clean_missing_open_path)
	assert(main.io_error_dialog.visible, "A failed clean Open should surface a file error")
	assert(not main.draft_dirty, "A failed clean Open must not make the current draft dirty")
	assert(main.experiment_name == clean_title_before_failed_open, "A failed clean Open must preserve the current title")
	assert(main.components.size() == clean_component_count_before_failed_open, "A failed clean Open must preserve the current components")
	assert(main.current_draft_path == clean_path_before_failed_open, "A failed clean Open must preserve the active draft path")
	assert(main.pending_open_path.is_empty(), "A failed clean Open must clear its pending path")
	main.io_error_dialog.hide()

	# Failed Save As must not change the active path or mark unsaved edits clean.
	main.experiment_name_input.text = "Unsaved after failed Save As"
	var path_before_failed_save: String = main.current_draft_path
	main._save_draft_to_path("res://must-not-write-from-ui.chemsim.json")
	assert(main.draft_dirty, "Failed Save As must preserve the dirty state")
	assert(main.current_draft_path == path_before_failed_save, "Failed Save As must preserve the previous current path")
	assert(main.io_error_dialog.visible, "Failed Save As should surface an actionable file error")
	main.io_error_dialog.hide()

	# Ordinary Save must use the remembered path and preserve the draft when a
	# user-owned transaction sidecar blocks the write.
	var ordinary_save_sidecar := save_as_path + ".tmp"
	var sidecar_file := FileAccess.open(ordinary_save_sidecar, FileAccess.WRITE)
	assert(sidecar_file != null, "The ordinary-save collision fixture should be writable")
	sidecar_file.store_string("user-owned sidecar data")
	sidecar_file.close()
	main._save_draft()
	assert(main.draft_dirty, "Failed ordinary Save must preserve the dirty state")
	assert(main.current_draft_path == path_before_failed_save, "Failed ordinary Save must preserve the current draft path")
	assert(main.io_error_dialog.visible, "Failed ordinary Save should surface the repository error")
	var preserved_sidecar := FileAccess.open(ordinary_save_sidecar, FileAccess.READ)
	assert(preserved_sidecar != null, "Failed ordinary Save must preserve the colliding sidecar")
	assert(preserved_sidecar.get_as_text() == "user-owned sidecar data", "Failed ordinary Save must not overwrite user-owned sidecar content")
	preserved_sidecar.close()
	main.io_error_dialog.hide()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ordinary_save_sidecar))

	# Previously, confirming Open with an empty pending path invoked New and
	# destroyed unsaved work. Refuse blank/whitespace paths before the dialog.
	main.discard_dialog.hide()
	var dirty_title_before_empty_open: String = main.experiment_name
	var dirty_path_before_empty_open: String = main.current_draft_path
	var dirty_count_before_empty_open: int = main.components.size()
	main._request_load_draft("  ")
	assert(main.io_error_dialog.visible, "Blank dirty Open must show an error")
	assert(not main.discard_dialog.visible, "Blank dirty Open must never offer a destructive discard confirmation")
	assert(main.experiment_name == dirty_title_before_empty_open, "Blank dirty Open must preserve unsaved title changes")
	assert(main.components.size() == dirty_count_before_empty_open, "Blank dirty Open must preserve draft components")
	assert(main.current_draft_path == dirty_path_before_empty_open and main.draft_dirty, "Blank dirty Open must preserve active path and dirty state")
	assert(main.pending_open_path.is_empty(), "Blank dirty Open must not retain a pending action")
	main.io_error_dialog.hide()

	# If the user confirms discarding edits but the requested file cannot be
	# opened, the current in-memory experiment must still survive unchanged.
	var title_before_failed_open: String = main.experiment_name
	var missing_open_path := "user://experiments/does-not-exist-ui-audit.chemsim.json"
	if FileAccess.file_exists(missing_open_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_open_path))
	main._request_load_draft(missing_open_path)
	assert(main.discard_dialog.visible, "Opening a different path while dirty must request confirmation")
	main.discard_dialog.confirmed.emit()
	assert(main.experiment_name == title_before_failed_open, "Failed Open must preserve the current experiment title")
	assert(main.draft_dirty, "Failed Open must preserve unsaved changes")
	assert(main.current_draft_path == path_before_failed_save, "Failed Open must preserve the current draft path")
	assert(main.io_error_dialog.visible, "Failed Open should surface a file error")
	main.io_error_dialog.hide()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_as_path))

	# Deleting a component during an active marker drag must remove both the
	# model and the visual drag handle, preventing a ghost marker on mouse move.
	main._select_component_for_placement(added_id)
	main.visual_field.dragging_marker_id = added_id
	main._remove_component(added_id)
	assert(main.components.is_empty(), "Removing a component should delete its draft record")
	assert(main.visual_field.markers.is_empty(), "Removing a component should remove its marker")
	assert(main.visual_field.dragging_marker_id == -1, "Deleting a dragged component must stop its visual drag")
	var deleted_component_motion := InputEventMouseMotion.new()
	deleted_component_motion.position = Vector2(80, 90)
	main.visual_field._gui_input(deleted_component_motion)
	assert(main.visual_field.markers.is_empty(), "Mouse motion after component deletion must not resurrect a visual marker")
	assert(main.draft_dirty, "Removing a component should mark the draft dirty")
	assert(main.selected_component_id == -1, "Removing the selected component must clear model selection")
	assert(main.visual_field.selected_marker_id == -1, "Removing the selected component must clear visual selection")
	assert(not main.visual_field.move_marker_by(added_id, Vector2.RIGHT, 0.01), "A removed component must not remain keyboard-movable")

	main._request_new_experiment()
	assert(main.discard_dialog.visible, "New experiment should request confirmation when the draft is dirty")
	main.discard_dialog.canceled.emit()
	assert(main.pending_open_path.is_empty(), "Cancelling New must leave no pending draft action")
	assert(main.draft_dirty, "Cancelling New confirmation must preserve the dirty state")
	assert(main.experiment_name == "Новый эксперимент", "Cancelling New confirmation must preserve the current experiment")
	assert(main.current_draft_path == save_as_path, "Cancelling New must preserve the current draft path")
	main._request_new_experiment()
	assert(main.discard_dialog.visible, "Retrying New should request confirmation again")
	assert(bool(main._accept_graph_series(synthetic_graph, "0.1").get("ok", false)), "Pre-New graph fixture should be insertable")

	main.discard_dialog.confirmed.emit()
	assert(main.components.is_empty(), "Confirming discard should create an empty experiment")
	assert(main.graph_view.series_by_quantity.is_empty(), "New experiment must discard cached graph values")
	assert(not main.draft_dirty, "A new empty experiment should start clean")
	assert(main.current_draft_path.is_empty(), "A confirmed New action should clear the previous draft path")
	assert(main.reaction_input.text.is_empty() and main.pressure_input.text.is_empty() and main.volume_input.text.is_empty(), "A new experiment should clear raw reaction and condition fields")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(round_trip_path))

	main.queue_free()
	print("Main draft-state integration tests passed")
	quit(0)
