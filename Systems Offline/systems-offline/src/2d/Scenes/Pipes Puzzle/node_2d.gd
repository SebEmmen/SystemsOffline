@tool
extends Node2D

@export var clockwise := true : set = _set_cw
@export var radius := 30.0
@export var color := Color(1, 0.85, 0.2)
@export var width := 6.0
@export var half_turn := false : set = _set_half

func _set_cw(v): clockwise = v; queue_redraw()
func _set_half(v): half_turn = v; queue_redraw()

func _draw() -> void:
	var sweep := PI * 1.5 if half_turn else PI * 0.9
	var start := -PI * 0.5 - sweep * 0.5
	var end := start + sweep
	if not clockwise:
		var t := start
		start = end
		end = t
	draw_arc(Vector2.ZERO, radius, start, end, 24, color, width)

	# arrowhead at the end of the arc
	var dir := 1.0 if clockwise else -1.0
	var tip := Vector2.from_angle(end) * radius
	var tangent := Vector2.from_angle(end + dir * PI * 0.5)
	var side := tangent.rotated(PI * 0.5)
	var head := 12.0
	draw_colored_polygon([
		tip + tangent * head,
		tip - tangent * 2.0 + side * head * 0.7,
		tip - tangent * 2.0 - side * head * 0.7,
	], color)
