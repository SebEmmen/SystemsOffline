class_name DialPuzzle2D
extends Control

signal solved
signal wrong_attempt

@export var dials: Array[Dial2D] = []
@export var check_button: Button
@export var feedback: Label   # optional


func _ready() -> void:
	check_button.pressed.connect(_on_check_pressed)
	_set_feedback("")
	activate()


func activate() -> void:
	_set_active(true)


func deactivate() -> void:
	for dial in dials:
		dial.stop_and_snap()
	_set_feedback("")
	_set_active(false)


func _set_active(on: bool) -> void:
	var locked: bool = SaveManager.dial_puzzle_completed
	for dial in dials:
		dial.can_turn = on and not locked
	check_button.disabled = not on or locked


func _set_feedback(t: String) -> void:
	if feedback:
		feedback.text = t


func _on_check_pressed() -> void:
	if SaveManager.dial_puzzle_completed:
		return
	for dial in dials:
		dial.stop_and_snap()   # make sure nothing is mid-turn
	if _is_correct():
		SaveManager.dial_puzzle_completed = true
		_set_feedback("ACCESS GRANTED")
		_set_active(false)
		solved.emit()
	else:
		_set_feedback("INCORRECT")
		wrong_attempt.emit()
		await get_tree().create_timer(1.5).timeout
		_set_feedback("")


func _is_correct() -> bool:
	for dial in dials:
		if not dial.is_correct():
			return false
	return true

func _on_button_pressed() -> void:
	print("Button pressed")
	_is_correct() # Replace with function body.
