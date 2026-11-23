@tool
extends Node2D
class_name CSWall

@export var dimensions: Vector2 = Vector2(110, 24):
	set(value):
		dimensions = value.max(Vector2(12, 12))
		queue_redraw()
@export var wall_color: Color = Color("#657681")

func _draw() -> void:
	var rect := Rect2(-dimensions * 0.5, dimensions)
	draw_rect(rect, wall_color)
	draw_rect(rect, Color("#b0c5cb"), false, 2.0)

func blocks_segment(a: Vector2, b: Vector2) -> bool:
	# Segment endpoints are expressed in global coordinates.
	var p := to_local(a)
	var q := to_local(b)
	var rect := Rect2(-dimensions * 0.5, dimensions)
	if rect.has_point(p) or rect.has_point(q):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(p, q, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false
