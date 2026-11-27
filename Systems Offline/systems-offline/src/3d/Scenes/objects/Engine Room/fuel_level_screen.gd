extends Node

signal solved

const TANKS_PATH  := "MarginContainer/VBoxContainer/Fuel Tanks"
const LABELS_PATH := "MarginContainer/VBoxContainer/Labels"

const CAPACITIES := [6, 3, 4]
const TARGETS    := [1, 3, 2]

const LINE_CORRECT := Color(0.1, 0.9, 0.3)
const SELECT_TINT  := Color(1.5, 1.5, 1.5)
const POUR_TIME    := 0.4

## The pouring puzzle (levels). Must match "Tank Levels Puzzle Id" in the ErrorScreen.
@export var puzzle_id: String = "fuel_fill_puzzle"
## The puzzle that adds fuel to Tank 1 (completed by pressing 9). Must match
## "Fuel Empty Puzzle Id" in the ErrorScreen and debug_fuel_puzzle_id on the player.
@export var fuel_add_puzzle_id: String = "fuel_adding_puzzle"
@export var auto_save_on_complete: bool = true

class Tank:
	var panel: PanelContainer
	var bar: ProgressBar
	var line: ColorRect
	var line_color: Color
	var capacity: int
	var target: int
	var level: int
	var tween: Tween

var tanks: Array[Tank] = []
var selected := -1
var is_solved := false


func _ready() -> void:
	if puzzle_id != "":
		SaveManager.is_puzzle_completed(puzzle_id)
	if fuel_add_puzzle_id != "":
		SaveManager.is_puzzle_completed(fuel_add_puzzle_id)

	if SaveManager.has_signal("puzzle_completed"):
		SaveManager.connect("puzzle_completed", _on_save_puzzle_completed)

	var root := get_node(TANKS_PATH)
	var _labels := get_node_or_null(LABELS_PATH)
	for i in CAPACITIES.size():
		var tank_node := root.get_node("Tank%d" % (i + 1))
		var t := Tank.new()
		t.panel = tank_node.get_node("PanelContainer")
		t.bar = t.panel.get_node("VBoxContainer/Tank%dFuelLevel" % (i + 1))
		t.line = tank_node.get_node("Target Line")
		t.line_color = t.line.color
		t.capacity = CAPACITIES[i]
		t.target = TARGETS[i]
		t.level = 0

		t.bar.min_value = 0
		t.bar.max_value = t.capacity
		t.bar.step = 0.0
		t.bar.show_percentage = false
		t.bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		t.bar.value = 0.0

		t.line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in t.panel.find_children("*", "Control", true, false):
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tank_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var hit: Control = tank_node.get_node("HitArea")
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect(_on_tank_input.bind(i))

		tanks.append(t)

	# Initial state from save data
	if _is_levels_completed():
		is_solved = true
		for t in tanks:
			_set_level_instant(t, t.target)
	elif _is_fuel_added():
		_set_level_instant(tanks[0], tanks[0].capacity)  # full (6)
	# else: everything stays empty

	_refresh()


func _is_fuel_added() -> bool:
	return fuel_add_puzzle_id != "" and SaveManager.is_puzzle_completed(fuel_add_puzzle_id)


func _is_levels_completed() -> bool:
	return puzzle_id != "" and SaveManager.is_puzzle_completed(puzzle_id)


func _on_save_puzzle_completed(completed_id: String) -> void:
	if completed_id == fuel_add_puzzle_id:
		# Fuel added -> fill Tank 1 to the top (only if nothing has been poured yet)
		if not is_solved and tanks[0].level == 0:
			_deselect()
			tanks[0].level = tanks[0].capacity
			_animate(tanks[0])
	elif completed_id == puzzle_id and not is_solved:
		# Levels solved by something external (e.g. debug)
		is_solved = true
		_deselect()
		for t in tanks:
			t.level = t.target
			_animate(t)
		solved.emit()


func _on_tank_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_tank(index)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset()


func _click_tank(index: int) -> void:
	if is_solved or not _is_fuel_added():
		return
	if selected == -1:
		if tanks[index].level > 0:
			selected = index
			tanks[index].panel.modulate = SELECT_TINT
	elif selected == index:
		_deselect()
	else:
		var from := selected
		_deselect()
		_pour(from, index)


func _deselect() -> void:
	if selected != -1:
		tanks[selected].panel.modulate = Color.WHITE
	selected = -1


func _pour(from: int, to: int) -> void:
	var src := tanks[from]
	var dst := tanks[to]
	var amount: int = min(src.level, dst.capacity - dst.level)
	if amount <= 0:
		return

	src.level -= amount
	dst.level += amount
	_animate(src)
	_animate(dst)

	if tanks.all(func(t): return t.level == t.target):
		_complete_puzzle()


func _complete_puzzle() -> void:
	if is_solved:
		return
	is_solved = true
	_deselect()

	if puzzle_id != "":
		SaveManager.complete_puzzle(puzzle_id)
		if auto_save_on_complete:
			SaveManager.save_game()
	solved.emit()


func _set_level_instant(t: Tank, value: int) -> void:
	if t.tween:
		t.tween.kill()
	t.level = value
	t.bar.value = float(value)
	t.bar.queue_redraw()


func _animate(t: Tank) -> void:
	if t.tween:
		t.tween.kill()
	t.tween = create_tween()
	t.tween.tween_property(t.bar, "value", float(t.level), POUR_TIME)
	t.tween.finished.connect(func() -> void:
		t.bar.value = float(t.level)
		t.bar.queue_redraw()
		_refresh()
	)


func _refresh() -> void:
	for t in tanks:
		t.line.color = LINE_CORRECT if t.level == t.target else t.line_color


func _reset() -> void:
	if is_solved:
		return
	_deselect()
	for i in tanks.size():
		var lvl: int = tanks[i].capacity if (i == 0 and _is_fuel_added()) else 0
		_set_level_instant(tanks[i], lvl)
	_refresh()
