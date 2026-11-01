extends Control
class_name ChemSimVisualField

const GRID_STEP := 32
const BACKGROUND := Color("#101923")
const GRID_COLOR := Color("#263746")
const TEXT_COLOR := Color("#8FA3B5")

func _ready() -> void:
	custom_minimum_size = Vector2(480, 320)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP
	var center := size * 0.5
	draw_circle(center, 4.0, Color("#607D91"))
	draw_string(ThemeDB.fallback_font, center + Vector2(-100, 30), "Поле эксперимента пока пусто", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR)
