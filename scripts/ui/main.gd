extends Control

const FormulaParserScript = preload("res://scripts/domain/formula_parser.gd")
const ReactionParserScript = preload("res://scripts/domain/reaction_parser.gd")
const ReactionBalancerScript = preload("res://scripts/domain/reaction_balancer.gd")

var _formula_input: LineEdit
var _reaction_input: LineEdit
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
	subtitle.text = "Технический прототип · формулы, уравнения и стехиометрия"
	root.add_child(subtitle)

	var formula_label := Label.new()
	formula_label.text = "Проверка химической формулы"
	root.add_child(formula_label)

	_formula_input = LineEdit.new()
	_formula_input.placeholder_text = "Например: Al2(SO4)3 или SO4^2-(aq)"
	_formula_input.text = "Ca(OH)2"
	root.add_child(_formula_input)

	var formula_button := Button.new()
	formula_button.text = "Разобрать формулу"
	formula_button.pressed.connect(_on_formula_pressed)
	root.add_child(formula_button)

	var reaction_label := Label.new()
	reaction_label.text = "Уравнение реакции (разделяйте вещества через пробел + пробел)"
	root.add_child(reaction_label)

	_reaction_input = LineEdit.new()
	_reaction_input.placeholder_text = "Например: H2 + O2 -> H2O"
	_reaction_input.text = "H2 + O2 -> H2O"
	root.add_child(_reaction_input)

	var reaction_button := Button.new()
	reaction_button.text = "Разобрать и сбалансировать"
	reaction_button.pressed.connect(_on_reaction_pressed)
	root.add_child(reaction_button)

	_output = RichTextLabel.new()
	_output.fit_content = true
	_output.scroll_active = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_output)
	_on_reaction_pressed()

func _on_formula_pressed() -> void:
	var result = FormulaParserScript.new().parse(_formula_input.text)
	_output.clear()
	if result.ok:
		_output.append_text("[b]Формула распознана[/b]\n")
		_output.append_text("Состав: %s\n" % JSON.stringify(result.element_counts))
		_output.append_text("Заряд: %d\n" % result.net_charge)
		_output.append_text("Фаза: %s" % (result.phase if not result.phase.is_empty() else "не задана"))
	else:
		_output.append_text("[color=tomato][b]%s[/b][/color]\n%s" % [result.error_code, result.error_message])

func _on_reaction_pressed() -> void:
	var parsed = ReactionParserScript.new().parse(_reaction_input.text)
	_output.clear()
	if not parsed.ok:
		_output.append_text("[color=tomato][b]%s[/b][/color]\n%s" % [parsed.error_code, parsed.error_message])
		return
	var balanced = ReactionBalancerScript.new().balance(parsed)
	if not balanced.ok:
		_output.append_text("[b]Уравнение распознано, но балансировка не выполнена[/b]\n")
		_output.append_text("%s: %s" % [balanced.error_code, balanced.error_message])
		return
	var left := _format_side(parsed.reactants, balanced.coefficients, 0)
	var right := _format_side(parsed.products, balanced.coefficients, parsed.reactants.size())
	_output.append_text("[color=green][b]Балансировка выполнена[/b][/color]\n")
	_output.append_text(left + " " + parsed.arrow + " " + right + "\n")
	_output.append_text("Коэффициенты: %s" % str(balanced.coefficients))

func _format_side(terms: Array[Dictionary], coefficients: Array[int], offset: int) -> String:
	var parts := PackedStringArray()
	for index in range(terms.size()):
		var coefficient := "" if coefficients[offset + index] == 1 else str(coefficients[offset + index]) + " "
		parts.append(coefficient + str(terms[index].formula))
	return " + ".join(parts)
