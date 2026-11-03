extends Node
class_name ChemSimSolverProcess

signal completed(result: Dictionary)

const SmokeContract = preload("res://scripts/a5_smoke_contract.gd")
const MAX_OUTPUT_BYTES := 4194304
const TIMEOUT_MS := 30000
var active_pid: int = -1
var request_path: String = ""
var response_path: String = ""
var active_request: Dictionary = {}
var started_ms: int = 0

static func solver_path() -> String:
	var suffix := ".exe" if OS.get_name() == "Windows" else ""
	# In a Godot editor or a headless integration test, use the checked-in
	# build output. In a packaged Windows export use a sibling executable.
	var editor_binary := ProjectSettings.globalize_path("res://bin/chemsim-solver" + suffix)
	if FileAccess.file_exists(editor_binary):
		return editor_binary
	var sidecar := OS.get_executable_path().get_base_dir().path_join("chemsim-solver" + suffix)
	if FileAccess.file_exists(sidecar):
		return sidecar
	return ""

func is_busy() -> bool:
	return active_pid > 0

func launch(request: Dictionary) -> Dictionary:
	if is_busy():
		return {"ok": false, "error": "Расчёт уже выполняется."}
	if str(request.get("contract_version", "")) != SmokeContract.CONTRACT_VERSION or str(request.get("kind", "")) != "simulation_request":
		return {"ok": false, "error": "Несовместимый формат запроса."}
	var exe := solver_path()
	if exe.is_empty():
		return {"ok": false, "error": "Не найден офлайн-решатель A4. Соберите bin/chemsim-solver и перезапустите приложение."}
	var job_dir := ProjectSettings.globalize_path("user://solver-jobs")
	if DirAccess.make_dir_recursive_absolute(job_dir) != OK:
		return {"ok": false, "error": "Невозможно создать локальный каталог для расчётов."}
	var nonce := str(request.get("message_id", "")).replace("-", "")
	if nonce.length() != 32 or not nonce.is_valid_hex_number():
		return {"ok": false, "error": "Недопустимый ID запроса."}
	request_path = job_dir.path_join(nonce + "-request.json")
	response_path = job_dir.path_join(nonce + "-response.json")
	if FileAccess.file_exists(request_path) or FileAccess.file_exists(response_path):
		request_path = ""
		response_path = ""
		return {"ok": false, "error": "Конфликт существующих файлов расчёта: данные не будут перезаписаны."}
	var serialized := JSON.stringify(request)
	if serialized.to_utf8_buffer().size() > 1048576:
		_clear_paths(false)
		return {"ok": false, "error": "Запрос слишком большой."}
	var output := FileAccess.open(request_path, FileAccess.WRITE)
	if output == null:
		_clear_paths(false)
		return {"ok": false, "error": "Не удалось создать файл задания."}
	output.store_string(serialized)
	output.flush()
	output.close()
	active_request = request.duplicate(true)
	active_pid = OS.create_process(exe, PackedStringArray(["--request", request_path, "--response", response_path]), false)
	if active_pid <= 0:
		active_request.clear()
		_clear_paths(true)
		return {"ok": false, "error": "Не удалось запустить локальный процесс решателя A4."}
	started_ms = Time.get_ticks_msec()
	set_process(true)
	return {"ok": true, "pid": active_pid}

func cancel() -> void:
	if not is_busy():
		return
	OS.kill(active_pid)
	_finish({"ok": false, "error": "Выполнение расчёта отменено пользователем."})

func _process(_delta: float) -> void:
	if not is_busy():
		return
	if Time.get_ticks_msec() - started_ms > TIMEOUT_MS:
		OS.kill(active_pid)
		_finish({"ok": false, "error": "Время выполнения A4 превысило 30 секунд. Процесс остановлен."})
		return
	if OS.is_process_running(active_pid):
		return
	if not FileAccess.file_exists(response_path):
		_finish({"ok": false, "error": "A4 завершился без файла результата. Проверьте версию и упаковку CLI."})
		return
	var file_size := FileAccess.get_file_as_bytes(response_path).size()
	if file_size == 0 or file_size > MAX_OUTPUT_BYTES:
		_finish({"ok": false, "error": "Размер ответа A4 не соответствует ограничениям."})
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(response_path))
	var admitted: Dictionary = SmokeContract.validate_response(parsed, active_request)
	_finish(admitted)

func _finish(result: Dictionary) -> void:
	active_pid = -1
	active_request.clear()
	set_process(false)
	_clear_paths(true)
	completed.emit(result)

func _clear_paths(remove_owned: bool) -> void:
	# Paths are generated only from a fresh UUID in our private user:// directory.
	# Never delete unrelated canonical drafts or arbitrary user-selected paths.
	if remove_owned:
		for path in [request_path, response_path]:
			if not path.is_empty() and FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	request_path = ""
	response_path = ""

func _exit_tree() -> void:
	if is_busy():
		OS.kill(active_pid)
		active_pid = -1
		_clear_paths(true)
