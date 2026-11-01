extends SceneTree

const DraftCodec = preload("res://scripts/draft_codec.gd")
const DraftRepository = preload("res://scripts/draft_repository.gd")

func _initialize() -> void:
	var components: Array[Dictionary] = [{
		"id": 1,
		"name": "Тест",
		"formula": "X",
		"amount": "raw amount",
		"unit": "custom unit",
		"phase": "custom phase",
		"position": Vector2(0.4, 0.6)
	}]
	var payload := DraftCodec.build_payload("Repository test", "raw reaction", "298.15", "raw P", "raw V", components)
	var path := "user://experiments/repository-test.chemsim.json"

	var saved := DraftRepository.save_draft(path, payload)
	assert(saved.ok, "Repository should save a valid UI draft")
	var loaded := DraftRepository.load_draft(path)
	assert(loaded.ok, "Repository should load a saved UI draft")
	assert(loaded.data.experiment_name == "Repository test", "Experiment name must round-trip")
	assert(loaded.data.components[0].formula == "X", "Raw formula text must round-trip")
	assert(loaded.data.conditions.pressure_raw == "raw P", "Raw condition text must round-trip")

	var rejected_save := DraftRepository.save_draft("res://must-not-write.json", payload)
	assert(not rejected_save.ok, "Repository must reject writes outside user://")
	var rejected_load := DraftRepository.load_draft("res://project.godot")
	assert(not rejected_load.ok, "Repository must reject reads outside user://")

	var traversal_save := DraftRepository.save_draft("user://experiments/../escape.json", payload)
	assert(not traversal_save.ok, "Repository must reject parent-directory traversal on save")
	var nested_traversal_load := DraftRepository.load_draft("user://experiments\\..\\escape.json")
	assert(not nested_traversal_load.ok, "Repository must reject Windows-style parent-directory traversal on load")
	var empty_path_save := DraftRepository.save_draft("user://", payload)
	assert(not empty_path_save.ok, "Repository must reject the user data root as a file path")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Draft repository tests passed")
	quit(0)
