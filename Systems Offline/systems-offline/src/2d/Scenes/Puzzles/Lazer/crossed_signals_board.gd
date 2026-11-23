@tool
class_name CrossedSignalsBoard
extends Control
## Draws and runs the complete 2D laser puzzle.
## Four freely movable universal relays are shared by two colors.
## Automatic routing finds two disjoint, two-relay paths; walls block line of sight.

signal completed
signal state_changed(message: String)

const BOARD_SIZE := Vector2(500.0, 380.0)
const RELAY_RADIUS := 12.0
const RED_EMITTER := Vector2(40.0, 65.0)
const BLUE_EMITTER := Vector2(40.0, 315.0)
const RED_RECEIVER := Vector2(460.0, 315.0)
const BLUE_RECEIVER := Vector2(460.0, 65.0)
const DOCKS := [
	Vector2(202.0, 351.0),
	Vector2(235.0, 351.0),
	Vector2(268.0, 351.0),
	Vector2(301.0, 351.0)
]
const WALLS := [
	Rect2(145.0, 0.0, 22.0, 165.0),
	Rect2(145.0, 245.0, 22.0, 135.0),
	Rect2(320.0, 75.0, 22.0, 230.0),
	Rect2(226.0, 152.0, 54.0, 76.0)
]
const COLOR_RED := Color(1.0, 0.37, 0.41)
const COLOR_BLUE := Color(0.36, 0.70, 1.0)
const COLOR_MINT := Color(0.32, 0.95, 0.70)
const COLOR_MUTED := Color(0.46, 0.64, 0.67)

var relay_positions: Array[Vector2] = [DOCKS[0], DOCKS[1], DOCKS[2], DOCKS[3]]
var relay_deployed: Array[bool] = [false, false, false, false]

var _drag_index: int = -1
var _drag_old_position := Vector2.ZERO
var _drag_old_deployed := false
var _red_path: Dictionary = {}
var _blue_path: Dictionary = {}
var _conflict := false
var _complete := false
var _status_text := "0/2 receivers online  |  0/4 relays deployed"
var _last_placement_failed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_evaluate()


func reset_board() -> void:
	_drag_index = -1
	_complete = false
	_last_placement_failed = false
	for i in range(DOCKS.size()):
		relay_positions[i] = DOCKS[i]
		relay_deployed[i] = false
	_evaluate()


func get_state_summary() -> String:
	return _status_text


func _gui_input(event: InputEvent) -> void:
	if _complete:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click: Vector2 = _screen_to_board(event.position)
			var index := _relay_at(click)
			if index >= 0:
				_drag_index = index
				_drag_old_position = relay_positions[index]
				_drag_old_deployed = relay_deployed[index]
				_last_placement_failed = false
				relay_deployed[index] = true  # Preview beam connections while dragging.
				_evaluate(false)
				accept_event()


func _input(event: InputEvent) -> void:
	if _drag_index < 0:
		return
	if event is InputEventMouseMotion:
		relay_positions[_drag_index] = _screen_to_board(get_local_mouse_position())
		_evaluate(false)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_drag(_screen_to_board(get_local_mouse_position()))
			get_viewport().set_input_as_handled()


func _finish_drag(position: Vector2) -> void:
	var index := _drag_index
	_drag_index = -1
	if index < 0:
		return

	# Each relay has its own dock. Dropping it there puts it away again.
	if position.distance_to(DOCKS[index]) <= 17.0:
		relay_positions[index] = DOCKS[index]
		relay_deployed[index] = false
		_last_placement_failed = false
	elif _can_place(index, position):
		relay_positions[index] = position
		relay_deployed[index] = true
		_last_placement_failed = false
	else:
		# Invalid placement: do not lose the player's previous arrangement.
		relay_positions[index] = _drag_old_position
		relay_deployed[index] = _drag_old_deployed
		_last_placement_failed = true

	_evaluate()


func _can_place(index: int, point: Vector2) -> bool:
	if point.x < 19.0 or point.x > BOARD_SIZE.x - 19.0:
		return false
	if point.y < 19.0 or point.y > BOARD_SIZE.y - 19.0:
		return false
	for wall in WALLS:
		if wall.grow(RELAY_RADIUS + 2.0).has_point(point):
			return false
	for device in [RED_EMITTER, BLUE_EMITTER, RED_RECEIVER, BLUE_RECEIVER]:
		if point.distance_to(device) < 29.0:
			return false
	for i in range(relay_positions.size()):
		if i != index and point.distance_to(relay_positions[i]) < 27.0:
			return false
	return true


func _relay_at(point: Vector2) -> int:
	for i in range(relay_positions.size() - 1, -1, -1):
		if relay_positions[i].distance_to(point) <= RELAY_RADIUS + 6.0:
			return i
	return -1


func _board_transform() -> Transform2D:
	var factor: float = minf(size.x / BOARD_SIZE.x, size.y / BOARD_SIZE.y)
	factor = maxf(factor, 0.0001)
	var offset := (size - BOARD_SIZE * factor) * 0.5
	return Transform2D(0.0, Vector2.ONE * factor, 0.0, offset)


func _screen_to_board(local_position: Vector2) -> Vector2:
	return _board_transform().affine_inverse() * local_position


func _clear_sight(a: Vector2, b: Vector2) -> bool:
	for wall in WALLS:
		if _segment_hits_rect(a, b, wall):
			return false
	return true


func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	# Liang-Barsky segment/rectangle intersection; detects even thin wall hits.
	var delta := b - a
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [a.x - rect.position.x, rect.end.x - a.x, a.y - rect.position.y, rect.end.y - a.y]
	var t_enter := 0.0
	var t_exit := 1.0
	for i in range(4):
		var pi: float = p[i]
		var qi: float = q[i]
		if absf(pi) < 0.000001:
			if qi < 0.0:
				return false
		else:
			var t: float = qi / pi
			if pi < 0.0:
				t_enter = maxf(t_enter, t)
			else:
				t_exit = minf(t_exit, t)
			if t_enter > t_exit:
				return false
	return t_exit >= 0.0 and t_enter <= 1.0


func _get_routes(is_red: bool) -> Array[Dictionary]:
	# Each channel must use exactly two different deployed relays.
	# The four universal relays can take either color, but never both.
	var emitter: Vector2 = RED_EMITTER if is_red else BLUE_EMITTER
	var receiver: Vector2 = RED_RECEIVER if is_red else BLUE_RECEIVER
	var result: Array[Dictionary] = []
	for i in range(relay_positions.size()):
		if not relay_deployed[i]:
			continue
		if not _clear_sight(emitter, relay_positions[i]):
			continue
		for j in range(relay_positions.size()):
			if j == i or not relay_deployed[j]:
				continue
			if not _clear_sight(relay_positions[i], relay_positions[j]):
				continue
			if not _clear_sight(relay_positions[j], receiver):
				continue
			var points: Array[Vector2] = [emitter, relay_positions[i], relay_positions[j], receiver]
			var total := 0.0
			for k in range(points.size() - 1):
				total += points[k].distance_to(points[k + 1])
			result.append({"ids": [i, j], "points": points, "score": total})
	return result


func _get_partial_path(is_red: bool) -> Dictionary:
	# Show the best visible emitter-to-relay beam before a full route exists.
	var emitter: Vector2 = RED_EMITTER if is_red else BLUE_EMITTER
	var receiver: Vector2 = RED_RECEIVER if is_red else BLUE_RECEIVER
	var best_score := INF
	var best: Dictionary = {}
	for i in range(relay_positions.size()):
		if not relay_deployed[i] or not _clear_sight(emitter, relay_positions[i]):
			continue
		var score: float = emitter.distance_to(relay_positions[i]) + relay_positions[i].distance_to(receiver)
		if score < best_score:
			best_score = score
			best = {"ids": [i], "points": [emitter, relay_positions[i]], "score": score}
	return best


func _evaluate(allow_completion: bool = true) -> void:
	_red_path = {}
	_blue_path = {}
	_conflict = false
	var red_routes: Array[Dictionary] = _get_routes(true)
	var blue_routes: Array[Dictionary] = _get_routes(false)
	var best_total := INF
	var has_pair := false

	# Search every pairing, rather than greedily assigning the first relay
	# seen. This avoids falsely rejecting a valid universal-relay layout.
	for red in red_routes:
		var red_ids: Array = red["ids"]
		for blue in blue_routes:
			var blue_ids: Array = blue["ids"]
			if red_ids[0] in blue_ids or red_ids[1] in blue_ids:
				continue
			var total: float = float(red["score"]) + float(blue["score"])
			if total < best_total:
				best_total = total
				_red_path = red
				_blue_path = blue
				has_pair = true

	if not has_pair:
		_red_path = _best_route_or_partial(red_routes, true)
		_blue_path = _best_route_or_partial(blue_routes, false)
		_conflict = not red_routes.is_empty() and not blue_routes.is_empty()

	var placed := 0
	for is_deployed in relay_deployed:
		if is_deployed:
			placed += 1

	if has_pair:
		_status_text = "SYSTEM RESTORED  |  Both receivers online"
	elif _conflict:
		_status_text = "RELAY CONFLICT  |  One relay cannot carry two colors"
	else:
		var online := int(not red_routes.is_empty()) + int(not blue_routes.is_empty())
		_status_text = "%d/2 routes ready  |  %d/4 relays deployed" % [online, placed]

	if _last_placement_failed:
		_status_text = "Invalid relay position  |  " + _status_text

	queue_redraw()
	state_changed.emit(_status_text)
	if allow_completion and has_pair and not _complete:
		_complete = true
		completed.emit()


func _best_route_or_partial(routes: Array[Dictionary], is_red: bool) -> Dictionary:
	if routes.is_empty():
		return _get_partial_path(is_red)
	var result: Dictionary = routes[0]
	for route in routes:
		if float(route["score"]) < float(result["score"]):
			result = route
	return result


func _draw() -> void:
	var transform := _board_transform()
	draw_set_transform(transform.origin, 0.0, Vector2.ONE * transform.x.length())
	_draw_board()
	_draw_beams()
	_draw_devices()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_board() -> void:
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color("#101e24"))
	for x in range(0, 501, 25):
		draw_line(Vector2(x, 0), Vector2(x, 380), Color(0.24, 0.42, 0.45, 0.20), 1.0)
	for y in range(0, 381, 25):
		draw_line(Vector2(0, y), Vector2(500, y), Color(0.24, 0.42, 0.45, 0.20), 1.0)
	for wall in WALLS:
		draw_rect(wall, Color("#566b72"))
		draw_rect(wall, Color("#95aeb5"), false, 1.2)
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color("#32675d"), false, 2.0)
	_draw_label(Vector2(156, 188), "GAP", Color("#bfd6d9"), 10)
	_draw_label(Vector2(331, 62), "BARRIER", Color("#bfd6d9"), 10)
	_draw_label(Vector2(253, 195), "CORE", Color("#d1dce0"), 11)
	_draw_label(Vector2(251, 331), "RELAY DOCKS", COLOR_MUTED, 9)

	for dock in DOCKS:
		draw_circle(dock, 16.0, Color(0.27, 0.50, 0.51, 0.18))
		draw_arc(dock, 16.0, 0.0, TAU, 32, Color(0.35, 0.65, 0.67, 0.35), 1.3, true)


func _draw_beams() -> void:
	_draw_path(_red_path, COLOR_RED)
	_draw_path(_blue_path, COLOR_BLUE)


func _draw_path(route: Dictionary, color: Color) -> void:
	if route.is_empty():
		return
	var points: Array = route["points"]
	for i in range(points.size() - 1):
		var start: Vector2 = points[i]
		var finish: Vector2 = points[i + 1]
		draw_line(start, finish, Color(color.r, color.g, color.b, 0.12), 10.0, true)
		draw_line(start, finish, Color(color.r, color.g, color.b, 0.85), 2.8, true)
		draw_line(start, finish, Color(1.0, 1.0, 1.0, 0.30), 0.8, true)


func _draw_devices() -> void:
	_draw_endpoint(RED_EMITTER, COLOR_RED, "RED IN", true, false)
	_draw_endpoint(BLUE_EMITTER, COLOR_BLUE, "BLUE IN", true, false)
	_draw_endpoint(RED_RECEIVER, COLOR_RED, "RED OUT", false, (_complete or _route_complete(_red_path)) and not _conflict)
	_draw_endpoint(BLUE_RECEIVER, COLOR_BLUE, "BLUE OUT", false, (_complete or _route_complete(_blue_path)) and not _conflict)

	for i in range(relay_positions.size()):
		var point: Vector2 = relay_positions[i]
		var placed := relay_deployed[i] or i == _drag_index
		var color := COLOR_MUTED
		if placed and _path_uses(_red_path, i):
			color = COLOR_RED
		if placed and _path_uses(_blue_path, i):
			color = COLOR_BLUE
		if _conflict and _path_uses(_red_path, i) and _path_uses(_blue_path, i):
			color = Color("#ffbd62")
		if i == _drag_index:
			color = COLOR_MINT if _can_place(i, point) else Color("#ff716c")
		draw_circle(point, 14.5, Color(color.r, color.g, color.b, 0.18))
		draw_circle(point, 11.0, Color("#12262b"))
		draw_arc(point, 12.0, 0.0, TAU, 32, color, 2.5, true)
		draw_circle(point, 4.3, color)
		_draw_label(point + Vector2(0, -20), "R%d" % (i + 1), Color("#d5e8e6"), 10)


func _draw_endpoint(point: Vector2, color: Color, label: String, emitter: bool, active: bool) -> void:
	var frame_color := color if emitter or active else COLOR_MUTED
	draw_circle(point, 17.0, Color(frame_color.r, frame_color.g, frame_color.b, 0.14))
	draw_circle(point, 13.0, Color("#102129"))
	draw_arc(point, 14.0, 0.0, TAU, 32, frame_color, 2.7, true)
	draw_circle(point, 5.0, frame_color if emitter or active else Color("#31424b"))
	var label_offset := -27.0 if point.y < 190.0 else 31.0
	_draw_label(point + Vector2(0, label_offset), label, frame_color, 10)


func _draw_label(position: Vector2, message: String, color: Color, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, position - Vector2(text_size.x * 0.5, 0.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _path_uses(path: Dictionary, index: int) -> bool:
	if path.is_empty():
		return false
	var ids: Array = path["ids"]
	return index in ids


func _route_complete(path: Dictionary) -> bool:
	if path.is_empty():
		return false
	var ids: Array = path["ids"]
	return ids.size() == 2
