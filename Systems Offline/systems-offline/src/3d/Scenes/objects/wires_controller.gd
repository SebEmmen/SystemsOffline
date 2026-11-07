
extends Node

@export_group("Wires")
@export var wire_1: Node3D
@export var wire_2: Node3D

@export_group("Puzzle")
@export var puzzle_id: String = "comms"

@export_group("Animation")
@export var delay_between_wires: float = 0.0

@export_group("Testing")
@export var debug_activate: bool = false


func _ready() -> void:
	# Only activate when the puzzle is complete.
	if not SaveManager.is_puzzle_completed(puzzle_id) \
	and not debug_activate:
		return

	# Ensure the wire scenes have initialized their materials.
	await get_tree().process_frame

	_activate_wire(wire_1)

	if delay_between_wires > 0.0:
		await get_tree().create_timer(
			delay_between_wires
		).timeout

	_activate_wire(wire_2)


func _activate_wire(wire: Node3D) -> void:
	if not is_instance_valid(wire):
		push_warning("WiresController: Wire not assigned.")
		return

	if wire.has_method("set_unlocked"):
		wire.call("set_unlocked")
	else:
		push_warning("Wire does not have set_unlocked().")
