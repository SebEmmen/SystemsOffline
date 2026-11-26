class_name MathPuzzle2D
extends Control

signal solved
signal wrong(attempts_left: int)   # -1 when attempts are unlimited

@export_group("Text")
@export var puzzle_title: String = "The Glyphs Lock"
@export var subtitle: String = "Each symbol hides a number."
@export var seal_text: String = "Seal I"

@export_group("Equations")
## One equation per row, 5 parts separated by spaces: glyph, operator, glyph, "=", result
@export var equations: PackedStringArray = [
	"■ + ⬤ = 6",
	"▲ - ■ = 1",
	"◆ - ▲ = 2",
	"⬤ + ⬤ = 4",
]

@export_group("Dials")
## The glyph shown under each dial (one per dial, left to right)
@export var dial_glyphs: PackedStringArray = ["■", "⬤", "▲", "◆"]
## The correct value for each dial (same order as dial_glyphs)
@export var solution: Array[int] = [4, 2, 5, 7]
## Optional starting values. Leave empty to start every dial at dial_min.
@export var start_values: Array[int] = []
@export var dial_min: int = 0
@export var dial_max: int = 9
@export var wrap_dials: bool = true

@export_group("Rules")
@export var max_attempts: int = 0   ## 0 = unlimited

@export_group("Feedback")
@export var correct_message: String = "The seal opens."
@export var wrong_message: String = "Nothing happens."
@export var locked_message: String = "The mechanism jams."
@export var correct_color: Color = Color("00d48a")
@export var wrong_color: Color = Color("d9534f")

@export_group("Colors")
@export var glyph_color: Color = Color("00d48a")
@export var operator_color: Color = Color("e0a526")
@export var result_color: Color = Color.WHITE

# Node names inside each equation row
const ROW_PARTS := ["Glyph", "MathSymbol", "Glyph2", "Equal", "Result"]

var values: Array[int] = []
var attempts: int = 0
var is_solved: bool = false
var is_locked: bool = false

var _dials: Array[Node] = []


func _ready() -> void:
	_set_text("%Title", puzzle_title)
	_set_text("%SubTitle", subtitle)
	_set_text("%SealLabel", seal_text)       # optional, ignored if missing
	_set_text("%FeedbackLabel", "")          # optional, ignored if missing

	_build_equations()
	_build_dials()
	%SubmitButton.pressed.connect(submit)


# ---------- Setup ----------

func _set_text(path: String, text: String) -> void:
	var node := get_node_or_null(path)
	if node:
		node.text = text


func _build_equations() -> void:
	var rows: Array = %Rows.get_children().filter(func(n): return n is HBoxContainer)

	for i in rows.size():
		var row: Node = rows[i]
		if i >= equations.size():
			row.visible = false
			continue

		row.visible = true
		var parts := equations[i].split(" ", false)

		for j in ROW_PARTS.size():
			var label: Label = row.get_node_or_null(ROW_PARTS[j])
			if label == null:
				push_warning("Row '%s' is missing a node named '%s'" % [row.name, ROW_PARTS[j]])
				continue

			label.text = parts[j] if j < parts.size() else ""

			var color := glyph_color
			if j == 1 or j == 3:      # MathSymbol, Equal
				color = operator_color
			elif j == 4:              # Result
				color = result_color
			label.add_theme_color_override("font_color", color)

	# Hide separators that follow hidden rows
	var children := %Rows.get_children()
	for i in children.size():
		if children[i] is HSeparator and i > 0:
			children[i].visible = children[i - 1].visible


func _build_dials() -> void:
	_dials = %DialRow.get_children()
	values.clear()

	for i in _dials.size():
		var dial: Node = _dials[i]

		if i >= solution.size():
			dial.visible = false
			values.append(dial_min)
			continue

		dial.visible = true
		var start := dial_min
		if i < start_values.size():
			start = clampi(start_values[i], dial_min, dial_max)
		values.append(start)

		var glyph: Label = dial.find_child("Glyph", true, false)
		if glyph and i < dial_glyphs.size():
			glyph.text = dial_glyphs[i]
			glyph.add_theme_color_override("font_color", glyph_color)

		var up: Button = dial.find_child("UpButton", true, false)
		var down: Button = dial.find_child("DownButton", true, false)

		# Avoid double-connecting if _build_dials runs again (e.g. reset())
		var up_call := change_dial.bind(i, 1)
		var down_call := change_dial.bind(i, -1)
		if up and not up.pressed.is_connected(up_call):
			up.pressed.connect(up_call)
		if down and not down.pressed.is_connected(down_call):
			down.pressed.connect(down_call)

		_refresh_dial(i)


# ---------- Dial control (public, so 3D input code can call these too) ----------

func change_dial(index: int, amount: int) -> void:
	if is_solved or is_locked:
		return
	if index < 0 or index >= values.size():
		return

	var v := values[index] + amount
	if wrap_dials:
		var span := dial_max - dial_min + 1
		v = dial_min + posmod(v - dial_min, span)
	else:
		v = clampi(v, dial_min, dial_max)

	values[index] = v
	_refresh_dial(index)


func _refresh_dial(index: int) -> void:
	var label: Label = _dials[index].find_child("Label", true, false)
	if label:
		label.text = str(values[index])


# ---------- Checking ----------

func submit() -> void:
	if is_solved or is_locked:
		return

	attempts += 1
	if _is_correct():
		is_solved = true
		_show_feedback(correct_message, correct_color)
		%SubmitButton.disabled = true
		solved.emit()
		return

	if max_attempts > 0 and attempts >= max_attempts:
		is_locked = true
		%SubmitButton.disabled = true
		_show_feedback(locked_message, wrong_color)
		wrong.emit(0)
	else:
		_show_feedback(wrong_message, wrong_color)
		wrong.emit(max_attempts - attempts if max_attempts > 0 else -1)


func _is_correct() -> bool:
	for i in solution.size():
		if i >= values.size() or values[i] != solution[i]:
			return false
	return true


func _show_feedback(msg: String, color: Color) -> void:
	var label := get_node_or_null("%FeedbackLabel")
	if label:
		label.text = msg
		label.add_theme_color_override("font_color", color)


## Call this to reset the puzzle (e.g. when the player walks away)
func reset() -> void:
	attempts = 0
	is_solved = false
	is_locked = false
	%SubmitButton.disabled = false
	_set_text("%FeedbackLabel", "")
	_build_dials()


var _flash_tween: Tween


# ---------- Called by the screen script ----------

func activate() -> void:
	if is_solved or is_locked:
		return
	_set_text("%FeedbackLabel", "")
	_clear_dial_colors()


func deactivate() -> void:
	_clear_dial_colors()
	_set_text("%FeedbackLabel", "")


# ---------- Feedback ----------

func _play_feedback(correct: bool) -> void:
	var color := correct_color if correct else wrong_color
	for dial in _dials:
		if not dial.visible:
			continue
		var num: Label = dial.find_child("Label", true, false)
		if num:
			num.add_theme_color_override("font_color", color)

	var bg := get_node_or_null("ColorRect")
	if bg:
		if _flash_tween:
			_flash_tween.kill()
		bg.modulate = Color(0.6, 1.0, 0.8) if correct else Color(1.0, 0.5, 0.5)
		_flash_tween = create_tween()
		_flash_tween.tween_property(bg, "modulate", Color.WHITE, 0.6)


func _clear_dial_colors() -> void:
	for dial in _dials:
		var num: Label = dial.find_child("Label", true, false)
		if num:
			num.remove_theme_color_override("font_color")
