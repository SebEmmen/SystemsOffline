@tool
extends Node2D
class_name CSDevice

enum Kind { EMITTER, RECEIVER, RELAY }
enum LaserColor { RED, BLUE }
@export var kind: Kind = Kind.RELAY:
	set(v):
		kind = v
		queue_redraw()
@export var laser_color: LaserColor = LaserColor.RED:
	set(v):
		laser_color = v
		queue_redraw()
@export var device_label: String = "":
	set(v):
		device_label = v
		queue_redraw()
@export var movable: bool = true
@export var starts_deployed: bool = true

func _draw() -> void:
	var tint := Color("#ff6464") if laser_color == LaserColor.RED else Color("#63b6ff")
	if kind == Kind.RELAY:
		tint = Color("#f4d35e")
	draw_circle(Vector2.ZERO, 15.0, Color("#10212a"))
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, tint, 3.0)
	if kind == Kind.RELAY:
		draw_circle(Vector2.ZERO, 6.0, tint)
	else:
		draw_circle(Vector2.ZERO, 5.0, tint)
	var label_text: String = device_label if not device_label.is_empty() else String(name)
	draw_string(ThemeDB.fallback_font, Vector2(-35, -23), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d5f1e7"))
