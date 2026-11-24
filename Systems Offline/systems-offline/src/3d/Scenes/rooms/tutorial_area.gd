
extends Area3D

@export_group("Tutorial Key")
@export var tutorial_key: Node3D
@export var respawn_height: float = 2
@export var check_interval: float = 0.2

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var player_was_inside: bool = false
var check_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Detect the player if they spawn inside the area.
	await get_tree().physics_frame

	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			player_was_inside = true
			break


func _physics_process(delta: float) -> void:
	if tutorial_key == null:
		return

	# Do not respawn a key that has been picked up.
	if not is_instance_valid(tutorial_key):
		return

	if tutorial_key.get("is_picked_up") == true:
		return

	check_timer += delta

	if check_timer < check_interval:
		return

	check_timer = 0.0

	if not is_key_inside_area():
		respawn_key()


func is_key_inside_area() -> bool:
	if not collision_shape.shape is BoxShape3D:
		return true

	var box: BoxShape3D = collision_shape.shape
	var local_position: Vector3 = collision_shape.to_local(
		tutorial_key.global_position
	)

	var half_size: Vector3 = box.size / 2.0

	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
		and absf(local_position.z) <= half_size.z
	)


func respawn_key() -> void:
	var box: BoxShape3D = collision_shape.shape

	var respawn_position: Vector3 = collision_shape.to_global(
		Vector3(
			0.0,
			-box.size.y / 2.0 + respawn_height,
			0.0
		)
	)

	if tutorial_key is RigidBody3D:
		var body: RigidBody3D = tutorial_key as RigidBody3D
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.global_position = respawn_position
		body.freeze = false
	else:
		tutorial_key.global_position = respawn_position

	print("Tutorial key left the room and was respawned.")


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
