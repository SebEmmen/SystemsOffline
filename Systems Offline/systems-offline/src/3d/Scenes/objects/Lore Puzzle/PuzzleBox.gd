class_name PuzzleBoxComponent
extends InspectComponent
## Reuses InspectComponent's monitor camera transition (enter_monitor / exit_monitor)
## without its wiring (SaveManager "comms", side screens, etc).


func _ready() -> void:
	_setup_audio_players()
	# Base _input() only handles exiting for the MONITOR type.
	inspect_type = InspectType.MONITOR

	if main_screen:
		main_screen.visible = true
	if lightning_off:
		lightning_off.visible = false

	if puzzle_id != "" and SaveManager.is_puzzle_completed(puzzle_id):
		can_interact = false


func interact() -> void:
	if not can_interact:
		return
	enter_monitor()   # moves the camera, then emits monitor_entered


## Called by the screen script after the puzzle is solved and the player has left the monitor.
func mark_solved() -> void:
	can_interact = false
	if puzzle_id != "":
		SaveManager.complete_puzzle(puzzle_id)
