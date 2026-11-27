class_name FuelPuzzleComponent
extends InspectComponent
## Reuses InspectComponent's monitor camera transition (enter_monitor / exit_monitor)
## for the fuel level screen without extra wiring.

@export var fuel_puzzle: Node


func _ready() -> void:
	_setup_audio_players()
	# Base _input() only handles exiting for the MONITOR type.
	inspect_type = InspectType.MONITOR

	if main_screen:
		main_screen.visible = true
	if lightning_off:
		lightning_off.visible = false

	if fuel_puzzle != null:
		if fuel_puzzle.has_signal("solved"):
			fuel_puzzle.connect("solved", _on_fuel_puzzle_solved)
		elif fuel_puzzle.has_signal("puzzle_solved"):
			fuel_puzzle.connect("puzzle_solved", _on_fuel_puzzle_solved)

	if puzzle_id != "" and SaveManager.is_puzzle_completed(puzzle_id):
		can_interact = false
		if fuel_puzzle != null and fuel_puzzle.has_method("set_solved"):
			fuel_puzzle.set_solved()


func interact() -> void:
	if not can_interact:
		return
	enter_monitor()   # moves the camera, then emits monitor_entered


func _on_fuel_puzzle_solved() -> void:
	mark_solved()


## Called by the screen script or puzzle node after the puzzle is solved.
func mark_solved() -> void:
	can_interact = false
	if puzzle_id != "":
		SaveManager.complete_puzzle(puzzle_id)
