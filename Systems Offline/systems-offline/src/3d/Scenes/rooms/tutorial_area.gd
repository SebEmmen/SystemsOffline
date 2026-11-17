
extends Area3D

var player_inside: bool = false


func _ready() -> void:
	monitoring = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Also detect a player who spawns inside the area.
	_check_initial_overlap()


func _check_initial_overlap() -> void:
	await get_tree().physics_frame

	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			player_inside = true
			print("Player started inside tutorial room.")
			break


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_inside = true
	print("Player entered tutorial room.")


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if not player_inside:
		return

	player_inside = false

	print("Player left tutorial room!")

	QuestManager.record_event("tutorial_room_escaped")
