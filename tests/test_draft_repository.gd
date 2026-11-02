extends SceneTree

const DraftCodec = preload("res://scripts/draft_codec.gd")
const DraftRepository = preload("res://scripts/draft_repository.gd")
const MAX_DRAFT_BYTES := 5 * 1024 * 1024

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

	var invalid_payload := payload.duplicate(true)
	invalid_payload.schema_version = 99
	var invalid_save_path := "user://experiments/invalid-schema.chemsim.json"
	var invalid_save := DraftRepository.save_draft(invalid_save_path, invalid_payload)
	assert(not invalid_save.ok, "Repository must reject malformed payloads before writing")
	assert(not FileAccess.file_exists(invalid_save_path), "Rejected payload must not create a draft file")

	var oversized_save_payload := payload.duplicate(true)
	oversized_save_payload.experiment_name = "x".repeat(MAX_DRAFT_BYTES + 1)
	var oversized_save_path := "user://experiments/oversized-save.chemsim.json"
	var oversized_save := DraftRepository.save_draft(oversized_save_path, oversized_save_payload)
	assert(not oversized_save.ok, "Repository must reject oversized payloads before writing")
	assert(not FileAccess.file_exists(oversized_save_path), "Oversized payload must not create a draft file")

	var oversized_path := "user://experiments/oversized.chemsim.json"
	_write_text(oversized_path, "x".repeat(MAX_DRAFT_BYTES + 1))
	var oversized_load := DraftRepository.load_draft(oversized_path)
	assert(not oversized_load.ok, "Repository must reject oversized draft files before JSON parsing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(oversized_path))

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

	var recovery_path := "user://experiments/recovery-test.chemsim.json"
	var recovery_backup := recovery_path + ".bak"
	assert(DraftRepository.save_draft(recovery_path, payload).ok, "Recovery fixture should be saved")
	var move_to_backup := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(recovery_path),
		ProjectSettings.globalize_path(recovery_backup)
	)
	assert(move_to_backup == OK, "Test should simulate interruption after moving the previous draft to backup")
	assert(not FileAccess.file_exists(recovery_path), "Canonical draft should be absent during simulated interruption")
	var recovered := DraftRepository.load_draft(recovery_path)
	assert(recovered.ok, "Load should recover the previous committed draft from .bak")
	assert(FileAccess.file_exists(recovery_path), "Recovery should restore the canonical draft path")
	assert(not FileAccess.file_exists(recovery_backup), "Recovery should consume the backup sidecar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_path))

	var corrupt_backup_path := "user://experiments/corrupt-backup.chemsim.json"
	var corrupt_backup := corrupt_backup_path + ".bak"
	_write_text(corrupt_backup, "{ definitely not valid json")
	var corrupt_backup_load := DraftRepository.load_draft(corrupt_backup_path)
	assert(not corrupt_backup_load.ok, "A corrupt backup must not be promoted to the canonical path")
	assert(not FileAccess.file_exists(corrupt_backup_path), "A corrupt backup must not create a canonical draft")
	assert(FileAccess.file_exists(corrupt_backup), "A corrupt backup must be preserved for manual recovery")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_backup))

	var corrupt_temp_path := "user://experiments/corrupt-temp.chemsim.json"
	var corrupt_temp := corrupt_temp_path + ".tmp"
	_write_text(corrupt_temp, "{ incomplete")
	var corrupt_temp_load := DraftRepository.load_draft(corrupt_temp_path)
	assert(not corrupt_temp_load.ok, "A corrupt temporary file must not be promoted")
	assert(not FileAccess.file_exists(corrupt_temp_path), "A corrupt temporary file must not create a canonical draft")
	assert(FileAccess.file_exists(corrupt_temp), "A corrupt temporary file must be preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_temp))

	var temp_recovery_path := "user://experiments/temp-recovery.chemsim.json"
	var temp_recovery_sidecar := temp_recovery_path + ".tmp"
	_write_text(temp_recovery_sidecar, JSON.stringify(payload))
	var temp_recovered := DraftRepository.load_draft(temp_recovery_path)
	assert(temp_recovered.ok, "A complete schema-valid temporary file should be recoverable when no canonical or backup exists")
	assert(FileAccess.file_exists(temp_recovery_path), "Recovered temporary content should become canonical")
	assert(not FileAccess.file_exists(temp_recovery_sidecar), "Successful temporary recovery should consume its sidecar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_recovery_path))

	# DirAccess.is_link detects symlinks and Windows reparse points. Exercise
	# an actual link to a location outside user:// on the Linux CI runner.
	var outside_target := OS.get_cache_dir().path_join("chemsim-symlink-target")
	DirAccess.make_dir_recursive_absolute(outside_target)
	var link_directory := DirAccess.open("user://experiments")
	assert(link_directory != null, "The experiment directory should be available for symlink testing")
	var link_error := link_directory.create_link(outside_target, "link-outside")
	assert(link_error == OK, "CI should be able to create a symlink fixture")
	var symlink_save := DraftRepository.save_draft("user://experiments/link-outside/escaped.json", payload)
	assert(not symlink_save.ok, "Repository must reject writes through a symlink escaping user://")
	var symlink_load := DraftRepository.load_draft("user://experiments/link-outside/escaped.json")
	assert(not symlink_load.ok, "Repository must reject reads through a symlink escaping user://")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://experiments/link-outside"))
	DirAccess.remove_absolute(outside_target)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Draft repository tests passed")
	quit(0)
