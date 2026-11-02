extends RefCounted
class_name ChemSimDraftRepository

const DraftCodec = preload("res://scripts/draft_codec.gd")
const MAX_DRAFT_BYTES := 5 * 1024 * 1024

static func save_draft(path: String, payload: Dictionary) -> Dictionary:
	if not _is_allowed_user_path(path):
		return _failure("Черновики разрешено сохранять только внутри пользовательской папки.")
	var validation := DraftCodec.decode_payload(payload)
	if not bool(validation.get("ok", false)):
		return _failure("Черновик не прошёл проверку схемы: " + String(validation.get("error", "неизвестная ошибка")))
	var serialized := JSON.stringify(payload, "\t")
	if serialized.to_utf8_buffer().size() > MAX_DRAFT_BYTES:
		return _failure("Черновик превышает допустимый размер 5 МиБ.")
	path = path.replace("\\", "/")
	if not _is_allowed_user_path(path + ".tmp") or not _is_allowed_user_path(path + ".bak"):
		return _failure("Сохранение/открытие запрещено: временный или резервный путь содержит ссылку на другой объект файловой системы.")
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_dir := ProjectSettings.globalize_path(path.get_base_dir())
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		return _failure("Не удалось создать папку для черновиков: " + str(dir_error))
	# Recover a previous interrupted transaction before starting another save.
	if not FileAccess.file_exists(path) and (FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp")):
		var recovery := load_draft(path)
		if not bool(recovery.get("ok", false)):
			return _failure("Сохранение остановлено: сначала требуется восстановить предыдущий черновик. " + String(recovery.get("error", "")))

	var temporary_path := path + ".tmp"
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(temporary_path):
		return _failure("Сохранение отменено: рядом уже существует временный файл " + temporary_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure("Не удалось открыть временный файл: " + str(FileAccess.get_open_error()))
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		return _failure("Ошибка записи черновика: " + str(write_error))

	var backup_path := path + ".bak"
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var had_previous_file := FileAccess.file_exists(path)
	if had_previous_file:
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(temporary_absolute)
			return _failure("Сохранение отменено: резервный файл уже существует " + backup_path)
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_absolute)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_absolute)
			return _failure("Не удалось подготовить замену файла: " + str(backup_error))

	var rename_error := DirAccess.rename_absolute(temporary_absolute, absolute_path)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		if had_previous_file:
			var restore_error := DirAccess.rename_absolute(backup_absolute, absolute_path)
			if restore_error != OK:
				return _failure("Не удалось завершить сохранение (" + str(rename_error) + ") и восстановить исходный файл (" + str(restore_error) + "). Резервная копия сохранена: " + backup_path)
		return _failure("Не удалось завершить сохранение: " + str(rename_error))
	if had_previous_file:
		DirAccess.remove_absolute(backup_absolute)
	return {"ok": true}

static func load_draft(path: String) -> Dictionary:
	if not _is_allowed_user_path(path):
		return _failure("Открывать черновики разрешено только внутри пользовательской папки.")
	path = path.replace("\\", "/")
	if not _is_allowed_user_path(path + ".tmp") or not _is_allowed_user_path(path + ".bak"):
		return _failure("Открытие запрещено: временный или резервный путь содержит ссылку на другой объект файловой системы.")
	var backup_path := path + ".bak"
	var temporary_path := path + ".tmp"

	# Never promote a sidecar before validating its size, JSON and complete schema.
	# If both sidecars exist while the canonical file is missing, prefer the
	# previous committed backup; leave the temporary file untouched for inspection.
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(backup_path):
			var backup_validation := _read_and_validate(backup_path)
			if not bool(backup_validation.get("ok", false)):
				return _failure("Резервная копия существует, но не прошла проверку; исходный файл не восстановлен. " + String(backup_validation.get("error", "")))
			var backup_restore_error := DirAccess.rename_absolute(
				ProjectSettings.globalize_path(backup_path),
				ProjectSettings.globalize_path(path)
			)
			if backup_restore_error != OK:
				return _failure("Не удалось восстановить проверенную резервную копию: " + str(backup_restore_error))
		elif FileAccess.file_exists(temporary_path):
			var temporary_validation := _read_and_validate(temporary_path)
			if not bool(temporary_validation.get("ok", false)):
				return _failure("Временный файл существует, но не прошёл проверку; он оставлен без изменений. " + String(temporary_validation.get("error", "")))
			var temporary_restore_error := DirAccess.rename_absolute(
				ProjectSettings.globalize_path(temporary_path),
				ProjectSettings.globalize_path(path)
			)
			if temporary_restore_error != OK:
				return _failure("Не удалось восстановить проверенный временный файл: " + str(temporary_restore_error))
		else:
			return _failure("Файл черновика не найден.")

	return _read_and_validate(path)

static func _read_and_validate(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Не удалось открыть файл: " + str(FileAccess.get_open_error()))
	if file.get_length() > MAX_DRAFT_BYTES:
		file.close()
		return _failure("Файл черновика превышает допустимый размер 5 МиБ.")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return DraftCodec.decode_payload(parsed)

static func _is_allowed_user_path(path: String) -> bool:
	if not path.begins_with("user://"):
		return false
	var relative_path := path.substr("user://".length()).replace("\\", "/")
	if relative_path.is_empty() or relative_path.begins_with("/"):
		return false
	var segments := relative_path.split("/")
	for segment in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return _has_no_symlink_components(segments)

static func _has_no_symlink_components(segments: PackedStringArray) -> bool:
	var current_directory := "user://"
	for index in range(segments.size()):
		var directory := DirAccess.open(current_directory)
		# A missing parent is valid for a future save. Existing parents must be
		# inspectable before traversing them.
		if directory == null:
			return not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(current_directory))
		var segment: String = segments[index]
		if directory.is_link(segment):
			return false
		if index == segments.size() - 1:
			return true
		var next_directory := current_directory.path_join(segment)
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(next_directory)):
			current_directory = next_directory
		elif FileAccess.file_exists(next_directory):
			return false
		else:
			return true
	return true

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
