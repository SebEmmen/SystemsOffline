class_name DialPuzzle2D
extends Control

signal solved
signal wrong_attempt

@export var monitor: Node3D
@export var dials: Array[Dial2D] = []
## Correct index per dial, same order as `dials`
@export var solution: Array[int] = []
@export var check_button: Button
@export var feedback: Label

@export_group("Debug")
@export var debug_always_active := false


func _ready() -> void:
	check_button.pressed.connect(_on_check_pressed)
	#feedback.text = ""

	if monitor:
		monitor.monitor_entered.connect(_set_active.bind(true))
		monitor.monitor_exited.connect(_on_monitor_exited)

	_set_active(debug_always_active)


func _on_monitor_exited() -> void:
	for dial in dials:
		dial.stop_and_snap()
	#feedback.text = ""
	_set_active(false)


func _set_active(on: bool) -> void:
	var locked := SaveManager.dial_puzzle_completed
	for dial in dials:
		dial.can_turn = on and not locked
	check_button.disabled = not on or locked


func _on_check_pressed() -> void:
	if SaveManager.dial_puzzle_completed:
		return
	if _is_correct():
		feedback.text = "ACCESS GRANTED"
		_set_active(false)
		solved.emit()
	else:
		feedback.text = "INCORRECT"
		wrong_attempt.emit()


func _is_correct() -> bool:
	if dials.size() != solution.size():
		push_warning("DialPuzzle2D: dials and solution sizes differ")
		return false
	for i in dials.size():
		if dials[i].current_index != solution[i]:
			return false
	return true
