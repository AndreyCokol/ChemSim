extends Control

const VisualFieldScript = preload("res://scripts/visual_field.gd")
const DraftCodec = preload("res://scripts/draft_codec.gd")
const DraftRepository = preload("res://scripts/draft_repository.gd")
const BG := Color("#0B1118")
const PANEL := Color("#151F2A")
const PANEL_ALT := Color("#1B2936")
const BORDER := Color("#2A3B4A")
const FG := Color("#E6EDF3")
const MUTED := Color("#91A4B5")
const ACCENT := Color("#62B6A5")
const WARNING := Color("#D8A85B")
const DANGER := Color("#D97878")

var status_label: Label
var composition_list: VBoxContainer
var experiment_name_input: LineEdit
var visual_field
var graph_title: Label
var reaction_input: LineEdit
var temperature_input: LineEdit
var pressure_input: LineEdit
var volume_input: LineEdit
var diagnostic_label: Label
var selected_component_id: int = -1
var editing_component_id: int = -1
var next_component_id: int = 1
var components: Array[Dictionary] = []
var experiment_name: String = "Новый эксперимент"
var draft_dirty: bool = false
var active_graph: String = "concentration"
var graph_buttons: Dictionary = {}
var add_dialog: AcceptDialog
var name_input: LineEdit
var formula_input: LineEdit
var amount_input: LineEdit
var amount_unit: OptionButton
var phase_input: OptionButton
var open_dialog: FileDialog
var save_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var io_error_dialog: AcceptDialog
var pending_open_path: String = ""

func _ready() -> void:
	_build_ui()
	_create_add_dialog()
	_refresh_composition()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	page.add_child(_header())

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(body_scroll)

	var body := HBoxContainer.new()
	body.custom_minimum_size.x = 1120
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	body_scroll.add_child(body)
	body.add_child(_left_panel())
	body.add_child(_center_panel())
	body.add_child(_right_panel())
	page.add_child(_timeline())
	page.add_child(_footer())

func _header() -> Control:
	var panel := _panel(PANEL, 0)
	panel.custom_minimum_size.y = 66
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(_pad(row, 18, 12, 18, 12))
	row.add_child(_label("ChemSim", 23, FG))
	row.add_child(_label("ЛАБОРАТОРИЯ ОБЩЕЙ ХИМИИ", 10, MUTED))
	experiment_name_input = LineEdit.new()
	experiment_name_input.placeholder_text = "Название эксперимента"
	experiment_name_input.text = experiment_name
	experiment_name_input.custom_minimum_size.x = 190
	experiment_name_input.text_changed.connect(_on_experiment_name_changed)
	row.add_child(experiment_name_input)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label("ИЗОТЕРМИЧЕСКАЯ МОДЕЛЬ", 10, ACCENT))
	var new_button := _button("＋ Новый эксперимент", true)
	new_button.pressed.connect(_request_new_experiment)
	row.add_child(new_button)
	var open_button := _button("Открыть черновик", false)
	open_button.pressed.connect(_open_draft_picker)
	row.add_child(open_button)
	var save_button := _button("Сохранить черновик", false)
	save_button.pressed.connect(_save_draft_picker)
	row.add_child(save_button)
	var settings := _button("Настройки", false)
	settings.disabled = true
	row.add_child(settings)
	return panel

func _left_panel() -> Control:
	var panel := _panel(PANEL, 1)
	panel.custom_minimum_size.x = 280
	panel.size_flags_horizontal = Control.SIZE_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(_pad(box, 14, 16, 14, 14))
	box.add_child(_section("СОСТАВ ЭКСПЕРИМЕНТА"))
	var hint := _label("Черновые записи. Формулы и значения пока не проверяются химическим ядром.", 11, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var add := _button("＋ Добавить вещество", true)
	add.pressed.connect(_open_add_dialog)
	box.add_child(add)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	composition_list = VBoxContainer.new()
	composition_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composition_list.add_theme_constant_override("separation", 7)
	scroll.add_child(composition_list)
	box.add_child(scroll)
	box.add_child(_separator())
	box.add_child(_section("УРАВНЕНИЕ РЕАКЦИИ"))
	var reaction_hint := _label("Ввод доступен как текстовый черновик. Разбор и балансировка подключаются отдельно.", 11, MUTED)
	reaction_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(reaction_hint)
	reaction_input = LineEdit.new()
	reaction_input.placeholder_text = "Например: H2 + O2 -> H2O"
	reaction_input.text_changed.connect(_on_reaction_changed)
	box.add_child(reaction_input)
	var balance := _button("Сбалансировать", false)
	balance.disabled = true
	balance.tooltip_text = "Ожидает подключения A2 Equation Parser & Balancer"
	box.add_child(balance)
	return panel

func _center_panel() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	var field_panel := _panel(BG, 1)
	field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	field_panel.add_child(_pad(column, 16, 14, 16, 10))
	var header := HBoxContainer.new()
	header.add_child(_section("ВИЗУАЛЬНОЕ ПОЛЕ"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_label("Позиция объектов — только визуальная", 11, MUTED))
	column.add_child(header)
	visual_field = VisualFieldScript.new()
	visual_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_field.marker_pressed.connect(_on_marker_pressed)
	visual_field.marker_moved.connect(_on_marker_moved)
	visual_field.field_pressed.connect(_on_field_pressed)
	column.add_child(visual_field)
	var note := _label("Выберите компонент слева → нажмите на поле, чтобы поставить маркер. Координаты не влияют на расчёт.", 11, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	center.add_child(field_panel)
	center.add_child(_graph_panel())
	return center

func _graph_panel() -> Control:
	var panel := _panel(PANEL, 1)
	panel.custom_minimum_size.y = 225
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(_pad(column, 16, 12, 16, 10))
	var row := HBoxContainer.new()
	graph_title = _section("КОНЦЕНТРАЦИЯ · ВРЕМЯ")
	row.add_child(graph_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_graph_tab("Концентрация", "concentration"))
	row.add_child(_graph_tab("Скорость", "rate"))
	row.add_child(_graph_tab("Температура", "temperature"))
	column.add_child(row)
	var chart_area := Control.new()
	chart_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_area.set_script(null)
	var chart_label := _label("Нет расчётных временных рядов", 12, MUTED)
	chart_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	chart_area.add_child(chart_label)
	column.add_child(chart_area)
	column.add_child(_label("Температура постоянна: изотермическая модель", 11, MUTED))
	return panel

func _right_panel() -> Control:
	var panel := _panel(PANEL, 1)
	panel.custom_minimum_size.x = 270
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(_pad(box, 14, 16, 14, 14))
	box.add_child(_section("УСЛОВИЯ ЭКСПЕРИМЕНТА"))
	box.add_child(_label("Температура · K", 11, MUTED))
	temperature_input = LineEdit.new()
	temperature_input.text = "298.15"
	temperature_input.editable = false
	temperature_input.tooltip_text = "MVP изотермический: температура постоянна"
	box.add_child(temperature_input)
	box.add_child(_label("Давление · единица не задана", 11, MUTED))
	pressure_input = LineEdit.new()
	pressure_input.placeholder_text = "Не задано"
	pressure_input.text_changed.connect(_on_condition_changed)
	box.add_child(pressure_input)
	box.add_child(_label("Объём · единица не задана", 11, MUTED))
	volume_input = LineEdit.new()
	volume_input.placeholder_text = "Не задано"
	volume_input.text_changed.connect(_on_condition_changed)
	box.add_child(volume_input)
	var model_note := _label("Модель: изотермическая. Ввод давления и объёма пока хранится как необработанный текст.", 10, MUTED)
	model_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(model_note)
	box.add_child(_separator())
	box.add_child(_section("СОСТОЯНИЕ РАСЧЁТА"))
	box.add_child(_status_row("Качество данных", "Не оценено"))
	box.add_child(_status_row("Применимость модели", "Не оценена"))
	box.add_child(_status_row("Численный статус", "Не запускался"))
	box.add_child(_status_row("Полнота результата", "Нет результата"))
	box.add_child(_separator())
	box.add_child(_section("ДИАГНОСТИКА"))
	diagnostic_label = _label("Черновик не проверен. Расчёт недоступен до подключения и проверки химических модулей.", 11, WARNING)
	diagnostic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(diagnostic_label)
	var run := _button("▶  Запустить расчёт", true)
	run.disabled = true
	run.tooltip_text = "Ожидает A1–A4 и утверждённых контрактов"
	box.add_child(run)
	var step := _button("Один шаг", false)
	step.disabled = true
	box.add_child(step)
	return panel

func _timeline() -> Control:
	var panel := _panel(PANEL_ALT, 0)
	panel.custom_minimum_size.y = 68
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(_pad(row, 16, 9, 16, 9))
	var rewind := _button("↶", false)
	rewind.disabled = true
	rewind.tooltip_text = "История и повторный расчёт будут подключены после согласования A4"
	row.add_child(rewind)
	var play := _button("▶", false)
	play.disabled = true
	row.add_child(play)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.editable = false
	row.add_child(slider)
	row.add_child(_label("t = —", 11, MUTED))
	var speed := OptionButton.new()
	speed.add_item("1×")
	speed.add_item("2×")
	speed.add_item("4×")
	speed.disabled = true
	row.add_child(speed)
	return panel

func _footer() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 28
	row.add_child(_pad(_label("OFFLINE · ЛОКАЛЬНЫЙ ПРОЕКТ", 10, MUTED), 12, 4, 0, 4))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	status_label = _label("Черновик · не проверен", 10, WARNING)
	row.add_child(_pad(status_label, 0, 4, 12, 4))
	return row

func _create_add_dialog() -> void:
	add_dialog = AcceptDialog.new()
	add_dialog.title = "Добавить вещество в черновик"
	add_dialog.dialog_text = "Запись не будет химически проверена."
	add_child(add_dialog)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 360
	form.add_theme_constant_override("separation", 8)
	add_dialog.add_child(form)
	form.add_child(_label("Название / обозначение", 11, MUTED))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Например: Вода"
	form.add_child(name_input)
	form.add_child(_label("Формула (без проверки)", 11, MUTED))
	formula_input = LineEdit.new()
	formula_input.placeholder_text = "H2O"
	form.add_child(formula_input)
	form.add_child(_label("Количество (текст)", 11, MUTED))
	amount_input = LineEdit.new()
	amount_input.placeholder_text = "Например: 1"
	form.add_child(amount_input)
	amount_unit = OptionButton.new()
	amount_unit.add_item("моль")
	amount_unit.add_item("г")
	amount_unit.add_item("мл")
	amount_unit.add_item("л")
	amount_unit.add_item("не задано")
	form.add_child(amount_unit)
	phase_input = OptionButton.new()
	phase_input.add_item("Фаза не указана")
	phase_input.add_item("Водный раствор")
	phase_input.add_item("Газ")
	phase_input.add_item("Жидкость")
	phase_input.add_item("Твёрдое")
	form.add_child(phase_input)
	add_dialog.confirmed.connect(_confirm_add_component)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Несохранённые изменения"
	discard_dialog.dialog_text = "Текущий черновик изменён. Продолжить без сохранения?"
	discard_dialog.confirmed.connect(_confirm_discard_pending_action)
	add_child(discard_dialog)
	io_error_dialog = AcceptDialog.new()
	io_error_dialog.title = "Не удалось выполнить операцию с черновиком"
	io_error_dialog.dialog_text = ""
	add_child(io_error_dialog)
	_create_file_dialogs()

func _open_add_dialog() -> void:
	editing_component_id = -1
	add_dialog.title = "Добавить вещество в черновик"
	name_input.text = ""
	formula_input.text = ""
	amount_input.text = ""
	amount_unit.select(0)
	phase_input.select(0)
	add_dialog.popup_centered()

func _open_edit_dialog(component_id: int) -> void:
	for item in components:
		if int(item.id) != component_id:
			continue
		editing_component_id = component_id
		add_dialog.title = "Изменить черновик вещества"
		name_input.text = str(item.name)
		formula_input.text = str(item.formula)
		amount_input.text = str(item.amount)
		_select_option_by_text(amount_unit, str(item.unit))
		_select_option_by_text(phase_input, str(item.phase))
		add_dialog.popup_centered()
		return

func _select_option_by_text(option: OptionButton, value: String) -> void:
	for index in range(option.get_item_count()):
		if option.get_item_text(index) == value:
			option.select(index)
			return
	option.select(option.get_item_count() - 1)

func _confirm_add_component() -> void:
	var display_name := name_input.text.strip_edges()
	var formula := formula_input.text.strip_edges()
	if display_name.is_empty() and formula.is_empty():
		status_label.text = "Нужно указать название или формулу"
		return
	var unit := amount_unit.get_item_text(amount_unit.get_selected())
	var phase := phase_input.get_item_text(phase_input.get_selected())
	var item_name := display_name if not display_name.is_empty() else formula
	if editing_component_id >= 0:
		for index in range(components.size()):
			if int(components[index].id) == editing_component_id:
				components[index].name = item_name
				components[index].formula = formula
				components[index].amount = amount_input.text.strip_edges()
				components[index].unit = unit
				components[index].phase = phase
				var marker_position: Vector2 = components[index].position
				if marker_position.x >= 0.0 and marker_position.y >= 0.0:
					visual_field.set_marker(editing_component_id, item_name, marker_position)
				break
		selected_component_id = editing_component_id
		status_label.text = "Черновик вещества обновлён: " + item_name
	else:
		var item := {
			"id": next_component_id,
			"name": item_name,
			"formula": formula,
			"amount": amount_input.text.strip_edges(),
			"unit": unit,
			"phase": phase,
			"position": Vector2(-1, -1)
		}
		next_component_id += 1
		components.append(item)
		selected_component_id = int(item.id)
		status_label.text = "Добавлен черновик: " + str(item.name)
	editing_component_id = -1
	draft_dirty = true
	_refresh_composition()

func _refresh_composition() -> void:
	if composition_list == null:
		return
	for child in composition_list.get_children():
		child.queue_free()
	if components.is_empty():
		var empty := _empty_card("Состав пока пуст", "Добавьте вещество. Запись останется черновой до проверки A1/A2.")
		composition_list.add_child(empty)
		return
	for item in components:
		var card := _panel(PANEL_ALT, 1)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		card.add_child(_pad(row, 9, 8, 9, 8))
		var title_row := HBoxContainer.new()
		title_row.add_child(_label(str(item.name), 13, FG))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(spacer)
		var edit := _button("Изменить", false)
		edit.pressed.connect(_open_edit_dialog.bind(int(item.id)))
		title_row.add_child(edit)
		var remove := _button("×", false)
		remove.custom_minimum_size.x = 30
		remove.pressed.connect(_remove_component.bind(int(item.id)))
		title_row.add_child(remove)
		row.add_child(title_row)
		var details := str(item.formula) + " · " + str(item.amount) + " " + str(item.unit)
		var detail_label := _label(details, 10, MUTED)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(detail_label)
		row.add_child(_label(str(item.phase), 10, MUTED))
		var place := _button("Разместить на поле", false)
		place.pressed.connect(_select_component_for_placement.bind(int(item.id)))
		row.add_child(place)
		if int(item.id) == selected_component_id:
			row.add_child(_label("Выбрано · нажмите на поле", 10, ACCENT))
		composition_list.add_child(card)

func _remove_component(component_id: int) -> void:
	for index in range(components.size() - 1, -1, -1):
		if int(components[index].id) == component_id:
			components.remove_at(index)
			break
	if selected_component_id == component_id:
		selected_component_id = -1
	visual_field.remove_marker(component_id)
	draft_dirty = true
	_refresh_composition()
	status_label.text = "Черновая запись удалена"

func _select_component_for_placement(component_id: int) -> void:
	selected_component_id = component_id
	_refresh_composition()
	status_label.text = "Нажмите на визуальное поле для размещения маркера"

func _on_field_pressed(normalized_position: Vector2) -> void:
	if selected_component_id < 0:
		status_label.text = "Сначала выберите компонент для размещения"
		return
	for index in range(components.size()):
		if int(components[index].id) == selected_component_id:
			components[index].position = normalized_position
			visual_field.set_marker(selected_component_id, str(components[index].name), normalized_position)
			draft_dirty = true
			status_label.text = "Маркер перемещён · химическое состояние не изменено"
			_refresh_composition()
			return

func _on_marker_pressed(component_id: int) -> void:
	selected_component_id = component_id
	_refresh_composition()
	status_label.text = "Выбран маркер · перетащите его или нажмите новое место"

func _on_marker_moved(component_id: int, normalized_position: Vector2) -> void:
	for index in range(components.size()):
		if int(components[index].id) == component_id:
			components[index].position = normalized_position
			draft_dirty = true
			return

func _on_experiment_name_changed(value: String) -> void:
	experiment_name = value
	draft_dirty = true
	_set_draft_status()

func _on_reaction_changed(_value: String) -> void:
	draft_dirty = true
	_set_draft_status()

func _on_condition_changed(_value: String) -> void:
	draft_dirty = true
	_set_draft_status()

func _set_draft_status() -> void:
	status_label.text = "Черновик изменён · химическая проверка не выполнена"
	diagnostic_label.text = "Введённые значения не интерпретируются и не конвертируются. Запуск расчёта заблокирован."

func _graph_tab(caption: String, mode: String) -> Button:
	var button := _button(caption, mode == active_graph)
	graph_buttons[mode] = button
	button.modulate = Color.WHITE if mode == active_graph else Color(0.68, 0.75, 0.82, 1.0)
	button.pressed.connect(func():
		active_graph = mode
		match mode:
			"concentration":
				graph_title.text = "КОНЦЕНТРАЦИЯ · ВРЕМЯ"
			"rate":
				graph_title.text = "СКОРОСТЬ · ВРЕМЯ"
			"temperature":
				graph_title.text = "ТЕМПЕРАТУРА · ВРЕМЯ"
		for graph_mode in graph_buttons:
			var graph_button: Button = graph_buttons[graph_mode]
			graph_button.modulate = Color.WHITE if graph_mode == active_graph else Color(0.68, 0.75, 0.82, 1.0)
	)
	return button

func _request_new_experiment() -> void:
	pending_open_path = ""
	if draft_dirty:
		discard_dialog.popup_centered()
		return
	_new_experiment()

func _new_experiment() -> void:
	components.clear()
	selected_component_id = -1
	editing_component_id = -1
	next_component_id = 1
	experiment_name = "Новый эксперимент"
	experiment_name_input.text = experiment_name
	reaction_input.text = ""
	pressure_input.text = ""
	volume_input.text = ""
	visual_field.clear_markers()
	_refresh_composition()
	draft_dirty = false
	diagnostic_label.text = "Создан пустой черновик. Расчёт не запускался."
	status_label.text = "Создан новый эксперимент"

func _create_file_dialogs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://experiments"))
	open_dialog = FileDialog.new()
	open_dialog.title = "Открыть черновик ChemSim"
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_USERDATA
	open_dialog.current_dir = "user://experiments"
	open_dialog.add_filter("*.chemsim.json", "Черновик ChemSim (JSON)")
	open_dialog.file_selected.connect(_request_load_draft)
	add_child(open_dialog)

	save_dialog = FileDialog.new()
	save_dialog.title = "Сохранить черновик ChemSim"
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_USERDATA
	save_dialog.current_dir = "user://experiments"
	save_dialog.current_file = "experiment-draft.chemsim.json"
	save_dialog.add_filter("*.chemsim.json", "Черновик ChemSim (JSON)")
	save_dialog.file_selected.connect(_save_draft_to_path)
	add_child(save_dialog)

func _open_draft_picker() -> void:
	open_dialog.popup_centered_ratio(0.7)

func _request_load_draft(path: String) -> void:
	pending_open_path = path
	if draft_dirty:
		discard_dialog.popup_centered()
		return
	_load_draft_from_path(path)
	pending_open_path = ""

func _confirm_discard_pending_action() -> void:
	if pending_open_path.is_empty():
		_new_experiment()
	else:
		_load_draft_from_path(pending_open_path)
	pending_open_path = ""

func _save_draft_picker() -> void:
	save_dialog.popup_centered_ratio(0.7)

func _save_draft_to_path(path: String) -> void:
	var payload: Dictionary = DraftCodec.build_payload(
		experiment_name,
		reaction_input.text,
		temperature_input.text,
		pressure_input.text,
		volume_input.text,
		components
	)
	var result: Dictionary = DraftRepository.save_draft(path, payload)
	if not bool(result.get("ok", false)):
		_show_io_error(str(result.get("error", "Не удалось сохранить черновик.")))
		return
	draft_dirty = false
	status_label.text = "Черновик сохранён · схема UI v1"
	diagnostic_label.text = "Сохранён только пользовательский черновик. Химическая валидность, расчётные данные и история симуляции не включены."

func _load_draft_from_path(path: String) -> void:
	var decoded: Dictionary = DraftRepository.load_draft(path)
	if not bool(decoded.get("ok", false)):
		_show_io_error(str(decoded.get("error", "Не удалось прочитать черновик.")) + " Текущий эксперимент не изменён.")
		return
	var data: Dictionary = decoded.data
	components = data.components
	visual_field.clear_markers()
	var max_id := 0
	for item in components:
		max_id = maxi(max_id, int(item.id))
		var position: Vector2 = item.position
		if position.x >= 0.0 and position.y >= 0.0:
			visual_field.set_marker(int(item.id), str(item.name), position)
	next_component_id = max_id + 1
	selected_component_id = -1
	editing_component_id = -1
	experiment_name = str(data.experiment_name)
	experiment_name_input.text = experiment_name
	reaction_input.text = str(data.reaction_text)
	var conditions: Dictionary = data.conditions
	pressure_input.text = str(conditions.get("pressure_raw", ""))
	volume_input.text = str(conditions.get("volume_raw", ""))
	_refresh_composition()
	draft_dirty = false
	pending_open_path = ""
	status_label.text = "Черновик загружен · химическая проверка не выполнена"
	diagnostic_label.text = "Загружен пользовательский черновик схемы v1. Перед расчётом требуется отдельная химическая проверка."

func _show_io_error(message: String) -> void:
	status_label.text = "Ошибка работы с файлом"
	diagnostic_label.text = message
	io_error_dialog.dialog_text = message
	io_error_dialog.popup_centered()

func _panel(color: Color, border_width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BORDER
	style.set_border_width_all(border_width)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _pad(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var wrapper := MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", left)
	wrapper.add_theme_constant_override("margin_top", top)
	wrapper.add_theme_constant_override("margin_right", right)
	wrapper.add_theme_constant_override("margin_bottom", bottom)
	wrapper.add_child(child)
	return wrapper

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _section(text_value: String) -> Label:
	return _label(text_value, 10, MUTED)

func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 11)
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT if primary else PANEL_ALT
	style.border_color = ACCENT if primary else BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 9
	style.content_margin_right = 9
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("#071510") if primary else FG)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button

func _empty_card(title_text: String, body_text: String) -> Control:
	var panel := _panel(PANEL_ALT, 1)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(_pad(box, 10, 10, 10, 10))
	box.add_child(_label(title_text, 12, FG))
	var body := _label(body_text, 10, MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return panel

func _status_row(caption: String, value: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(caption, 10, MUTED))
	box.add_child(_label(value, 11, WARNING))
	return box

func _separator() -> Control:
	var line := HSeparator.new()
	line.add_theme_color_override("separator", BORDER)
	return line
