
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
	print("PAN: Function started")
	print("PAN: Transition camera = ", transition_camera)
	print("PAN: Active camera = ", get_tree().root.get_camera_3d())
	print("PAN: Multitool piece = ", multitool_piece)

	if transition_camera == null:
		push_error("PAN: Transition camera is not assigned!")
		return

	if multitool_piece == null:
		push_error("PAN: Multitool piece is not assigned!")
		return

	# Get the camera currently being used to inspect the puzzle.
	var inspect_camera := get_tree().root.get_camera_3d()

	if inspect_camera == null:
		push_error("PAN: No active camera found!")
		return

	if inspect_camera == transition_camera:
		push_error("PAN: Transition camera is already active!")
		return

	print("PAN: Starting camera animation")

	# Save the inspect camera's position and rotation.
	var start_transform := (
		inspect_camera.global_transform.orthonormalized()
	)

	# Save the desired transition camera position and rotation.
	var target_transform := (
		transition_camera.global_transform.orthonormalized()
	)

	# Save the transition camera's original properties.
	var original_transform := transition_camera.transform
	var original_top_level := transition_camera.top_level

	var start_fov := inspect_camera.fov
	var target_fov := transition_camera.fov

	# Position the transition camera at the inspect camera.
	transition_camera.top_level = true
	transition_camera.global_transform = start_transform
	transition_camera.fov = start_fov

	# Switch to the transition camera.
	transition_camera.make_current()

	# Calculate where the Multitool piece should move.
	var piece_target := (
		multitool_piece.global_position + Vector3.UP * 0.3
	)

	# Create one tween for the camera and Multitool piece.
	var tween := create_tween()

	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Move and rotate the camera toward the device.
	tween.tween_property(
		transition_camera,
		"global_transform",
		target_transform,
		camera_duration
	)

	# Animate the camera's field of view.
	tween.tween_property(
		transition_camera,
		"fov",
		target_fov,
		camera_duration
	)

	# Raise the Multitool piece at the same time.
	tween.tween_property(
		multitool_piece,
		"global_position",
		piece_target,
		3.0
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished

	print("PAN: Camera reached transition position")

	# Create a second tween to return to inspection.
	var return_tween := create_tween()

	return_tween.set_parallel(true)
	return_tween.set_trans(Tween.TRANS_QUAD)
	return_tween.set_ease(Tween.EASE_IN_OUT)

	# Move the camera back.
	return_tween.tween_property(
		transition_camera,
		"global_transform",
		start_transform,
		return_duration
	)

	# Restore the original field of view.
	return_tween.tween_property(
		transition_camera,
		"fov",
		start_fov,
		return_duration
	)

	await return_tween.finished

	# Switch back to the original inspect camera.
	inspect_camera.make_current()

	# Restore the transition camera to its original position.
	transition_camera.top_level = original_top_level
	transition_camera.transform = original_transform
	transition_camera.fov = target_fov

	print("PAN: Camera transition complete")
	
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F9 and event.pressed and not event.echo:
			print("DEBUG: F9 pressed, starting camera transition")
			pan_to_multitool_piece()
