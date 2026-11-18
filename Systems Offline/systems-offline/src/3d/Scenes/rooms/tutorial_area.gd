
extends Area3D

var player_was_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Detect the player if they spawn inside the area.
	await get_tree().physics_frame

	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			player_was_inside = true
			break


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_was_inside = true


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if not player_was_inside:
		return

	player_was_inside = false

	# Only complete the quest after solving the keypad.
	if not QuestManager.has_event("tutorial_code_discovered"):
		return

	# Prevent completing the quest multiple times.
	if QuestManager.has_event("tutorial_room_escaped"):
		return

	print("Player escaped the tutorial room!")

	QuestManager.record_event("tutorial_room_escaped")
