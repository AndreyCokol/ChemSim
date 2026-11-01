extends Control

const VisualFieldScript = preload("res://scripts/visual_field.gd")
const BG := Color("#0B1118")
const PANEL := Color("#151F2A")
const PANEL_ALT := Color("#1B2936")
const BORDER := Color("#2A3B4A")
const FG := Color("#E6EDF3")
const MUTED := Color("#91A4B5")
const ACCENT := Color("#62B6A5")
const WARNING := Color("#D8A85B")

var status_label: Label
var graph_title: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	page.add_child(_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	page.add_child(body)
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
	var title := _label("ChemSim", 23, FG)
	row.add_child(title)
	row.add_child(_label("ЛАБОРАТОРИЯ ОБЩЕЙ ХИМИИ", 10, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label("ИЗОТЕРМИЧЕСКАЯ МОДЕЛЬ", 10, ACCENT))
	var new_button := _button("＋ Новый эксперимент", true)
	new_button.pressed.connect(func(): status_label.text = "Создан пустой черновик интерфейса")
	row.add_child(new_button)
	var settings := _button("Настройки", false)
	settings.disabled = true
	row.add_child(settings)
	return panel

func _left_panel() -> Control:
	var panel := _panel(PANEL, 1)
	panel.custom_minimum_size.x = 250
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(_pad(box, 16, 18, 16, 16))
	box.add_child(_section("СОСТАВ ЭКСПЕРИМЕНТА"))
	box.add_child(_empty_card("Пока нет компонентов", "Добавленные вещества и их количества появятся здесь."))
	var add := _button("＋ Добавить вещество", false)
	add.disabled = true
	box.add_child(add)
	box.add_child(_separator())
	box.add_child(_section("УРАВНЕНИЕ РЕАКЦИИ"))
	var hint := _label("Введите реакцию для анализа состава и стехиометрии.", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var input := LineEdit.new()
	input.placeholder_text = "Например: H2 + O2 -> H2O"
	input.editable = false
	box.add_child(input)
	var balance := _button("Сбалансировать", false)
	balance.disabled = true
	box.add_child(balance)
	return panel

func _center_panel() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	var field_panel := _panel(BG, 1)
	field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	field_panel.add_child(_pad(column, 18, 16, 18, 12))
	var header := HBoxContainer.new()
	header.add_child(_section("ВИЗУАЛЬНОЕ ПОЛЕ"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_label("Визуализация · не физическая модель", 11, MUTED))
	column.add_child(header)
	var field := Control.new()
	field.set_script(VisualFieldScript)
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(field)
	var note := _label("Цвета и координаты объектов не влияют на химический расчёт.", 11, MUTED)
	column.add_child(note)
	center.add_child(field_panel)
	center.add_child(_graph_panel())
	return center

func _graph_panel() -> Control:
	var panel := _panel(PANEL, 1)
	panel.custom_minimum_size.y = 235
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(_pad(column, 18, 14, 18, 12))
	var row := HBoxContainer.new()
	graph_title = _section("Концентрация · время")
	row.add_child(graph_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_graph_tab("Концентрация", "Концентрация · время"))
	row.add_child(_graph_tab("Скорость", "Скорость · время"))
	row.add_child(_graph_tab("Температура", "Температура · время"))
	column.add_child(row)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_label("График появится после получения расчётных данных", 12, MUTED))
	column.add_child(center)
	column.add_child(_label("Температура постоянна: изотермическая модель", 11, MUTED))
	return panel

func _right_panel() -> Control:
	var panel := _panel(PANEL, 1)
	panel.custom_minimum_size.x = 300
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(_pad(box, 16, 18, 16, 16))
	box.add_child(_section("УСЛОВИЯ ЭКСПЕРИМЕНТА"))
	box.add_child(_value_row("Температура", "298.15 K"))
	box.add_child(_value_row("Давление", "—"))
	box.add_child(_value_row("Объём", "—"))
	box.add_child(_value_row("Модель", "Изотермическая"))
	box.add_child(_separator())
	box.add_child(_section("СОСТОЯНИЕ РАСЧЁТА"))
	box.add_child(_status_row("Качество данных", "Не оценено"))
	box.add_child(_status_row("Применимость модели", "Не оценена"))
	box.add_child(_status_row("Численный статус", "Не запускался"))
	box.add_child(_status_row("Полнота результата", "Нет результата"))
	box.add_child(_separator())
	box.add_child(_section("ДИАГНОСТИКА"))
	var diag := _label("Расчётные модули ещё не подключены. Здесь будут отображаться предупреждения и пояснения.", 12, MUTED)
	diag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(diag)
	var run := _button("▶  Запустить расчёт", true)
	run.disabled = true
	box.add_child(run)
	var step := _button("Один шаг", false)
	step.disabled = true
	box.add_child(step)
	return panel

func _timeline() -> Control:
	var panel := _panel(PANEL_ALT, 0)
	panel.custom_minimum_size.y = 72
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(_pad(row, 18, 10, 18, 10))
	var rewind := _button("↶", false)
	rewind.disabled = true
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
	row.custom_minimum_size.y = 30
	row.add_child(_pad(_label("OFFLINE · ЛОКАЛЬНЫЙ ПРОЕКТ", 10, MUTED), 14, 5, 0, 5))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	status_label = _label("Ожидание ввода", 10, MUTED)
	row.add_child(_pad(status_label, 0, 5, 14, 5))
	return row

func _graph_tab(caption: String, mode: String) -> Button:
	var button := _button(caption, false)
	button.pressed.connect(func(): graph_title.text = mode)
	return button

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
	return _label(text_value, 11, MUTED)

func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 12)
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT if primary else PANEL_ALT
	style.border_color = ACCENT if primary else BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("#071510") if primary else FG)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button

func _empty_card(title_text: String, body_text: String) -> Control:
	var panel := _panel(PANEL_ALT, 1)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(_pad(box, 12, 12, 12, 12))
	box.add_child(_label(title_text, 13, FG))
	var body := _label(body_text, 11, MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return panel

func _value_row(caption: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_label(caption, 11, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label(value, 12, FG))
	return row

func _status_row(caption: String, value: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(caption, 11, MUTED))
	box.add_child(_label(value, 12, WARNING))
	return box

func _separator() -> Control:
	var line := HSeparator.new()
	line.add_theme_color_override("separator", BORDER)
	return line
