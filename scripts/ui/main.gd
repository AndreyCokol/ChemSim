extends Control

const FormulaParserScript = preload("res://scripts/domain/formula_parser.gd")

var _input: LineEdit
var _output: RichTextLabel

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.offset_left = 32
	root.offset_top = 24
	root.offset_right = -32
	root.offset_bottom = -24
	add_child(root)

	var title := Label.new()
	title.text = "ChemSim — химический эксперимент"
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Ранний технический прототип · парсер химических формул"
	root.add_child(subtitle)

	_input = LineEdit.new()
	_input.placeholder_text = "Например: Al2(SO4)3 или SO4^2-(aq)"
	_input.text = "Ca(OH)2"
	root.add_child(_input)

	var parse_button := Button.new()
	parse_button.text = "Разобрать формулу"
	parse_button.pressed.connect(_on_parse_pressed)
	root.add_child(parse_button)

	_output = RichTextLabel.new()
	_output.fit_content = true
	_output.scroll_active = false
	root.add_child(_output)
	_on_parse_pressed()

func _on_parse_pressed() -> void:
	var parser = FormulaParserScript.new()
	var result = parser.parse(_input.text)
	_output.clear()
	if result.ok:
		_output.append_text("[b]Формула распознана[/b]\n")
		_output.append_text("Состав: %s\n" % JSON.stringify(result.element_counts))
		_output.append_text("Заряд: %d\n" % result.net_charge)
		_output.append_text("Фаза: %s" % (result.phase if not result.phase.is_empty() else "не задана"))
	else:
		_output.append_text("[color=tomato][b]%s[/b][/color]\n%s" % [result.error_code, result.error_message])
