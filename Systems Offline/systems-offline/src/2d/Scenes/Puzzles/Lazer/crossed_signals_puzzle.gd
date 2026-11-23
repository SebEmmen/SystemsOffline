class_name CrossedSignalsPuzzle
extends Control
## Standalone interface for Crossed Signals.
## Connect puzzle_solved to a room object / SaveManager when desired.

signal puzzle_solved

@onready var board: CrossedSignalsBoard = $Margin/Layout/BoardFrame/Board
@onready var status_label: Label = $Margin/Layout/Header/Status
@onready var hint_label: Label = $Margin/Layout/HintLabel
@onready var reset_button: Button = $Margin/Layout/Controls/ResetButton
@onready var hint_button: Button = $Margin/Layout/Controls/HintButton

var _hint_index := 0
var _solved := false

const HINTS := [
	"HINT 1/3: Both colors must travel through two relays. The walls block all beams.",
	"HINT 2/3: Red must route around the lower end of the right wall. Blue must route above it.",
	"HINT 3/3: Try two relays near (195, 280) and (303, 341) for red; (195, 145) and (300, 40) for blue."
]


func _ready() -> void:
	board.completed.connect(_on_board_completed)
	board.state_changed.connect(_on_board_state_changed)
	reset_button.pressed.connect(_on_reset_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	_on_board_state_changed(board.get_state_summary())


func _on_board_state_changed(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override(
		"font_color", Color("#65efb2") if _solved else Color("#b7d7d3")
	)


func _on_board_completed() -> void:
	if _solved:
		return
	_solved = true
	status_label.text = "SYSTEM RESTORED  |  Both receivers online"
	status_label.add_theme_color_override("font_color", Color("#65efb2"))
	hint_label.text = "Success. Both color channels are online; the relays are now locked."
	puzzle_solved.emit()


func _on_reset_pressed() -> void:
	_solved = false
	_hint_index = 0
	hint_label.text = "Drag R1–R4 freely. Every color needs exactly two relays; a relay cannot serve both colors."
	board.reset_board()


func _on_hint_pressed() -> void:
	hint_label.text = HINTS[_hint_index]
	_hint_index = (_hint_index + 1) % HINTS.size()
