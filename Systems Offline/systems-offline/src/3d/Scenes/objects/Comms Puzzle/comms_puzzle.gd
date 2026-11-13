
class_name DialPuzzle2D
extends Control

signal solved
signal wrong_attempt

@export_group("Puzzle")
@export var dials: Array[Dial2D] = []
@export var check_button: Button
@export var feedback: Label
@export var valid: Label3D
@export var invalid: Label3D

@export_group("Multitool")
@export var multitool_piece: Node3D

@export_group("Camera Transition")
@export var transition_camera: Camera3D
@export var camera_duration: float = 0.7
@export var return_duration: float = 0.5
var _pan_tween: Tween
var _return_tween: Tween
var _panning: bool = false
var _pan_cancelled: bool = false

func _ready() -> void:
	check_button.pressed.connect(_on_check_pressed)
	_set_feedback("")
	activate()


func activate() -> void:
	_set_active(true)


func deactivate() -> void:
	cancel_pan()  # <-- add this

	for dial in dials:
		dial.stop_and_snap()

	_set_feedback("")
	_set_active(false)

func _exit_tree() -> void:
	cancel_pan()
	

func cancel_pan() -> void:
	if not _panning:
		return
	_pan_cancelled = true
	# Fast-forward so `await ...finished` resumes instead of hanging forever.
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.custom_step(9999.0)
	if _return_tween and _return_tween.is_valid():
		_return_tween.custom_step(9999.0)

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
		dial.stop_and_snap()

	if _is_correct():
		SaveManager.dial_puzzle_completed = true
		multitool_piece.can_interact = true
		invalid.visible = false
		valid.visible = true

		_set_active(false)

		print("Puzzle correct. Starting camera transition.")

		await pan_to_multitool_piece()

		print("Camera transition finished.")

		solved.emit()

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
	_is_correct()


func pan_to_multitool_piece() -> void:
	if _panning:
		return

	if transition_camera == null or multitool_piece == null:
		push_error("PAN: Transition camera or Multitool piece not assigned!")
		return

	var inspect_camera := get_tree().root.get_camera_3d()
	if inspect_camera == null or inspect_camera == transition_camera:
		push_error("PAN: No valid inspect camera!")
		return
	
	multitool_piece.visible = true
	_panning = true
	_pan_cancelled = false

	var start_transform := inspect_camera.global_transform.orthonormalized()
	var target_transform := transition_camera.global_transform.orthonormalized()
	var original_transform := transition_camera.transform
	var original_top_level := transition_camera.top_level
	var start_fov := inspect_camera.fov
	var target_fov := transition_camera.fov

	transition_camera.top_level = true
	transition_camera.global_transform = start_transform
	transition_camera.fov = start_fov
	transition_camera.make_current()

	var piece_target := multitool_piece.global_position + Vector3.UP * 0.3

	_pan_tween = create_tween()
	_pan_tween.set_parallel(true)
	_pan_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_property(transition_camera, "global_transform", target_transform, camera_duration)
	_pan_tween.tween_property(transition_camera, "fov", target_fov, camera_duration)
	_pan_tween.tween_property(multitool_piece, "global_position", piece_target, 3.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await _pan_tween.finished

	if not _pan_cancelled:
		_return_tween = create_tween()
		_return_tween.set_parallel(true)
		_return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_return_tween.tween_property(transition_camera, "global_transform", start_transform, return_duration)
		_return_tween.tween_property(transition_camera, "fov", start_fov, return_duration)
		await _return_tween.finished

	# Only hand the view back if the transition camera still owns it
	if not _pan_cancelled and transition_camera.current \
			and is_instance_valid(inspect_camera) and inspect_camera.is_inside_tree():
		inspect_camera.make_current()

	transition_camera.top_level = original_top_level
	transition_camera.transform = original_transform
	transition_camera.fov = target_fov

	_panning = false
	
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F9 and event.pressed and not event.echo:
			print("DEBUG: F9 pressed, starting camera transition")
			pan_to_multitool_piece()
