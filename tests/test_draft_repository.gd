extends SceneTree

const DraftCodec = preload("res://scripts/draft_codec.gd")
const DraftRepository = preload("res://scripts/draft_repository.gd")

func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Test fixture should be writable: " + path)
	file.store_string(value)
	file.close()

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Test fixture should be readable: " + path)
	var value := file.get_as_text()
	file.close()
	return value

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

	var temp_collision_path := "user://experiments/temp-collision.chemsim.json"
	var temp_sidecar := temp_collision_path + ".tmp"
	_write_text(temp_sidecar, "user-owned temp data")
	var temp_collision := DraftRepository.save_draft(temp_collision_path, payload)
	assert(not temp_collision.ok, "Repository must not overwrite an existing temporary sidecar")
	assert(_read_text(temp_sidecar) == "user-owned temp data", "Existing temporary sidecar content must be preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_sidecar))

	var backup_collision_path := "user://experiments/backup-collision.chemsim.json"
	var backup_sidecar := backup_collision_path + ".bak"
	assert(DraftRepository.save_draft(backup_collision_path, payload).ok, "Backup-collision fixture should be created")
	_write_text(backup_sidecar, "user-owned backup data")
	var backup_collision := DraftRepository.save_draft(backup_collision_path, payload)
	assert(not backup_collision.ok, "Repository must not overwrite an existing backup sidecar")
	assert(_read_text(backup_sidecar) == "user-owned backup data", "Existing backup sidecar content must be preserved")
	var original_after_collision := DraftRepository.load_draft(backup_collision_path)
	assert(original_after_collision.ok, "Original draft must remain readable after sidecar collision")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_sidecar))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_collision_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Draft repository tests passed")
	quit(0)
