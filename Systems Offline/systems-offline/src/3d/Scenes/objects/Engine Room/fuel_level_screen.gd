extends Node

const TANKS_PATH  := "MarginContainer/VBoxContainer/Fuel Tanks"
const LABELS_PATH := "MarginContainer/VBoxContainer/Labels"

const CAPACITIES := [6, 3, 4]
const TARGETS    := [1, 3, 2]
const START      := [6, 0, 0]

const LINE_CORRECT := Color(0.1, 0.9, 0.3)
const SELECT_TINT  := Color(1.5, 1.5, 1.5)
const POUR_TIME    := 0.4

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
var solved := false

func _ready() -> void:
	var root := get_node(TANKS_PATH)
	var labels := get_node_or_null(LABELS_PATH)
	for i in CAPACITIES.size():
		var tank_node := root.get_node("Tank%d" % (i + 1))
		var t := Tank.new()
		t.panel = tank_node.get_node("PanelContainer")
		t.bar = t.panel.get_node("VBoxContainer/Tank%dFuelLevel" % (i + 1))
		t.line = tank_node.get_node("Target Line")
		t.line_color = t.line.color
		t.capacity = CAPACITIES[i]
		t.target = TARGETS[i]
		t.level = START[i]

		t.bar.min_value = 0
		t.bar.max_value = t.capacity
		t.bar.step = 0.0
		t.bar.show_percentage = false
		t.bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		t.bar.value = t.level

		# Everything inside the tank and the target line ignores the mouse...
		t.line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in t.panel.find_children("*", "Control", true, false):
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tank_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# ...and only the HitArea receives the click.
		var hit: Control = tank_node.get_node("HitArea")
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect(_on_tank_input.bind(i))

		tanks.append(t)
	_refresh()

func _make_clickable(control: Control, index: int) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(_on_tank_input.bind(index))

func _on_tank_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_tank(index)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset()

func _click_tank(index: int) -> void:
	if solved:
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

	# Lock immediately, based on the logical levels
	solved = tanks.all(func(t): return t.level == t.target)

func _animate(t: Tank) -> void:
	if t.tween:
		t.tween.kill()
	t.tween = create_tween()
	t.tween.tween_property(t.bar, "value", t.level, POUR_TIME)
	t.tween.finished.connect(_refresh)

func _refresh() -> void:
	for t in tanks:
		t.line.color = LINE_CORRECT if t.level == t.target else t.line_color

func _reset() -> void:
	_deselect()
	solved = false
	for i in tanks.size():
		tanks[i].level = START[i]
		if tanks[i].tween:
			tanks[i].tween.kill()
		tanks[i].bar.value = START[i]
	_refresh()
