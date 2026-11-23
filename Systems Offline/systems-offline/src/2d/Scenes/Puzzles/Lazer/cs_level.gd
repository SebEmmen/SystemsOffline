@tool
extends Node2D
class_name CSLevel

signal puzzle_solved
signal receiver_changed(receiver: CSDevice, powered: bool)

@export var max_relay_link_distance: float = 1000.0
@export var require_all_receivers: bool = true
@export var preview_in_editor: bool = true
@export var freeze_after_solved: bool = true
@export var background_size: Vector2 = Vector2(960, 600)

var _dragged: CSDevice
var _drag_offset := Vector2.ZERO
var _powered: Dictionary = {}
var _links: Array[Dictionary] = []
var _relay_colors: Dictionary = {}
var _solved := false

func _ready() -> void:
	set_process(true)
	if not Engine.is_editor_hint():
		set_process_unhandled_input(true)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_update_network()
	queue_redraw()

func _devices() -> Array[CSDevice]:
	var result: Array[CSDevice] = []
	for node in get_children():
		if node is CSDevice:
			result.append(node)
	return result

func _walls() -> Array[CSWall]:
	var result: Array[CSWall] = []
	for node in get_children():
		if node is CSWall:
			result.append(node)
	return result

func _line_clear(a: Vector2, b: Vector2) -> bool:
	for wall in _walls():
		if wall.blocks_segment(a, b):
			return false
	return true

func _update_network() -> void:
	var devices := _devices()
	var previous := _powered.duplicate()
	_powered.clear()
	_links.clear()
	_relay_colors.clear()
	for device in devices:
		if device.kind == CSDevice.Kind.RECEIVER:
			_powered[device] = false
	# Each relay can transmit only one color. A source claiming a relay
	# reserves it for that color. Deterministic order: red, then blue.
	for color in [CSDevice.LaserColor.RED, CSDevice.LaserColor.BLUE]:
		var frontier: Array[CSDevice] = []
		var reached: Dictionary = {}
		for device in devices:
			if device.kind == CSDevice.Kind.EMITTER and device.laser_color == color:
				frontier.append(device)
				reached[device] = true
		while not frontier.is_empty():
			var current := frontier.pop_front()
			for candidate in devices:
				if candidate == current or reached.has(candidate):
					continue
				if candidate.kind == CSDevice.Kind.EMITTER:
					continue
				if candidate.kind == CSDevice.Kind.RECEIVER and candidate.laser_color != color:
					continue
				if candidate.kind == CSDevice.Kind.RELAY and _relay_colors.has(candidate) and _relay_colors[candidate] != color:
					continue
				if current.global_position.distance_to(candidate.global_position) > max_relay_link_distance:
					continue
				if not _line_clear(current.global_position, candidate.global_position):
					continue
				reached[candidate] = true
				_links.append({"a": current, "b": candidate, "color": color})
				if candidate.kind == CSDevice.Kind.RELAY:
					_relay_colors[candidate] = color
					frontier.append(candidate)
				elif candidate.kind == CSDevice.Kind.RECEIVER:
					_powered[candidate] = true
	for receiver in _powered:
		if previous.get(receiver, false) != _powered[receiver] and not Engine.is_editor_hint():
			receiver_changed.emit(receiver, _powered[receiver])
	for barrier in _walls():
		if barrier is CSBarrier:
			var gate: CSBarrier = barrier as CSBarrier
			var target := gate.get_node_or_null(gate.receiver_path)
			var should_open := target != null and _powered.get(target, false)
			if gate.is_open != should_open:
				gate.is_open = should_open
				barrier.queue_redraw()
	if Engine.is_editor_hint():
		return
	var receivers := _powered.keys()
	var complete := not receivers.is_empty()
	for receiver in receivers:
		if not _powered[receiver]:
			complete = false
	if complete and not _solved:
		_solved = true
		puzzle_solved.emit()

func _unhandled_input(event: InputEvent) -> void:
	if _solved and freeze_after_solved:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse := get_global_mouse_position()
			for device in _devices():
				if device.kind == CSDevice.Kind.RELAY and device.movable and mouse.distance_to(device.global_position) <= 20.0:
					_dragged = device
					_drag_offset = device.global_position - mouse
					get_viewport().set_input_as_handled()
					break
		else:
			if _dragged != null:
				_dragged = null
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragged != null:
		var desired := get_global_mouse_position() + _drag_offset
		var valid := true
		for wall in _walls():
			if wall.blocks_segment(desired, desired + Vector2(0.01, 0.01)):
				valid = false
				break
		if valid:
			_dragged.global_position = desired
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, background_size), Color("#0e1c24"))
	draw_rect(Rect2(Vector2.ZERO, background_size), Color("#2d555e"), false, 2.0)
	for link in _links:
		var color := Color("#ff6767") if link["color"] == CSDevice.LaserColor.RED else Color("#62b7ff")
		draw_line(to_local(link["a"].global_position), to_local(link["b"].global_position), color, 3.0, true)

func reset_level() -> void:
	_solved = false
	_update_network()
