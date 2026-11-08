class_name DialPuzzle2D
extends Control

signal solved
signal wrong_attempt

@export var dials: Array[Dial2D] = []
@export var check_button: Button
@export var feedback: Label   # optional
@export var valid: Label3D
@export var invalid: Label3D
@export var multitool_piece: Node3D


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
		invalid.visible = false
		valid.visible = true
		
		_set_active(false)
		solved.emit()
		pan_to_multitool_piece()
	else:
		_set_feedback("INCORRECT")
		valid.visible = false
		invalid.visible = true
	
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

func pan_to_multitool_piece() -> void:
	var piece_tween := create_tween()
	var piece_target := multitool_piece.global_position + Vector3.UP * 0.3
	piece_tween.tween_property(
		multitool_piece,
		"global_position",
		piece_target,
		3.0
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await piece_tween.finished
