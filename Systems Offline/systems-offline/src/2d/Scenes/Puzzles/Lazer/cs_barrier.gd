@tool
extends CSWall
class_name CSBarrier

@export var receiver_path: NodePath
@export var open_when_powered: bool = true
var is_open := false

func _draw() -> void:
	var tint := Color("#44e6a7") if is_open else Color("#ff9c54")
	var rect := Rect2(-dimensions * 0.5, dimensions)
	draw_rect(rect, tint * Color(1, 1, 1, 0.28))
	draw_rect(rect, tint, false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-20, -dimensions.y * 0.5 - 7), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)

func blocks_segment(a: Vector2, b: Vector2) -> bool:
	return not is_open and super.blocks_segment(a, b)
