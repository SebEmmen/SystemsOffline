class_name HoldableInteractableComponent
extends InteractableComponent

@export_group("Shader Glow Effect")
@export var enable_glow: bool = true
@export var glow_color: Color = Color(0.851, 0.574, 0.095, 1.0) # Warm golden glow
@export var glow_energy: float = 3.0 # Intensity of the emission glow

@export_group("Drop Physics")
@export var drop_distance: float = 0
@export var drop_height: float = 1.2
@export var drop_forward_force: float = 2
@export var drop_upward_force: float = 1.5
@export var inherit_player_momentum: float = 0.7

var is_held: bool = false
var original_collision_layer: int = 1
var original_collision_mask: int = 1
var active_player: CharacterBody3D = null
var active_hand_marker: Marker3D = null

func _ready() -> void:
	super._ready()
	
	if object_ref is CollisionObject3D:
		original_collision_layer = object_ref.collision_layer
		original_collision_mask = object_ref.collision_mask


func interact() -> void:
	if is_held:
		return

	active_player = get_tree().get_first_node_in_group("player")
	if object_ref is RigidBody3D:
		var body: RigidBody3D = object_ref as RigidBody3D
		body.add_collision_exception_with(active_player)

	if not active_player:
		printerr(
			"HoldableInteractableComponent: Player not found!"
		)
		return

	if "hand_marker" in active_player and active_player.hand_marker:
		active_hand_marker = active_player.hand_marker
	else:
		printerr(
			"HoldableInteractableComponent: Hand marker missing!"
		)
		return

	if "current_held_item" in active_player:
		if active_player.current_held_item and active_player.current_held_item != self:
			active_player.current_held_item.drop_item()

		active_player.current_held_item = self

	# Move the object into the player's hand.
	object_ref.reparent(active_hand_marker)

	reset_position()
	disable_physics()

	is_held = true

	# Remove the glow.
	set_object_glow(false)

	play_primary_se()

	Notification.show_pickup_notification(object_ref.item_data)

	print("Successfully picked up item!")

	# ----------------------------------------------
	# QUEST PROGRESS
	# ----------------------------------------------

	if not quest_event_id.is_empty():
		print("Holdable quest event: ", quest_event_id)

		QuestManager.record_event(quest_event_id)


func drop_item() -> void:
	if not is_held:
		return

	var world_root: Node = get_tree().current_scene
	object_ref.reparent(world_root, true)

	if active_player:
		# Get the player's forward direction.
		var drop_dir: Vector3 = -active_player.global_transform.basis.z
		drop_dir.y = 0.0
		drop_dir = drop_dir.normalized()

		# Position the object at the player's horizontal center.
		var spawn_position: Vector3 = (
			active_player.global_position
			+ active_player.up_direction * drop_height
			+ drop_dir * drop_distance
		)

		# Forward throw + upward arc + player movement momentum.
		var throw_velocity: Vector3 = (
			drop_dir * drop_forward_force
			+ active_player.up_direction * drop_upward_force
			+ active_player.velocity * inherit_player_momentum
		)

		if object_ref is RigidBody3D:
			var body: RigidBody3D = object_ref as RigidBody3D

			# Position while frozen, then reactivate physics.
			body.freeze = true
			body.global_position = spawn_position
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO

			body.collision_layer = original_collision_layer
			body.collision_mask = original_collision_mask
			# Prevent the dropped item from colliding with the player.
			body.add_collision_exception_with(active_player)

			body.freeze = false
			body.sleeping = false
			body.linear_velocity = throw_velocity

		else:
			# Non-rigidbody objects cannot follow a physics arc.
			if object_ref is CollisionObject3D:
				object_ref.collision_layer = original_collision_layer
				object_ref.collision_mask = original_collision_mask

			object_ref.global_position = spawn_position

	# Restore the emission glow.
	if enable_glow:
		set_object_glow(true)

	is_held = false

	if active_player and "current_held_item" in active_player:
		if active_player.current_held_item == self:
			active_player.current_held_item = null

	active_player = null
	active_hand_marker = null

	Notification.show_pickup_notification(object_ref.item_data)
	print("Item dropped with forward momentum and arc!")


# Helper function to apply or remove the emissive glow material override on meshes
func set_object_glow(glowing: bool) -> void:
	if not object_ref:
		return
		
	var meshes: Array[MeshInstance3D] = []
	if object_ref is MeshInstance3D:
		meshes.append(object_ref as MeshInstance3D)
	for child in object_ref.find_children("*", "MeshInstance3D", true, true):
		meshes.append(child as MeshInstance3D)
		
	for mesh in meshes:
		if glowing:
			var mat = StandardMaterial3D.new()
			var original_mat = mesh.get_active_material(0)
			if original_mat is StandardMaterial3D:
				mat.albedo_color = original_mat.albedo_color
				mat.albedo_texture = original_mat.albedo_texture
			
			# Enable emission for a self-illuminated shader glow effect
			mat.emission_enabled = true
			mat.emission = glow_color
			mat.emission_energy_multiplier = glow_energy
			mesh.material_override = mat
		else:
			mesh.material_override = null

func get_object_aabb(node: Node3D) -> AABB:
	var combined_aabb = AABB()
	var first = true
	
	if node is VisualInstance3D:
		combined_aabb = node.get_aabb()
		first = false
		
	for child in node.find_children("*", "VisualInstance3D", true, true):
		if first:
			combined_aabb = child.get_aabb()
			first = false
		else:
			combined_aabb = combined_aabb.merge(child.get_aabb())
			
	return combined_aabb

func reset_position() -> void:
	object_ref.position = Vector3.ZERO
	object_ref.rotation = Vector3.ZERO

func disable_physics() -> void:
	if object_ref is RigidBody3D:
		object_ref.freeze = true
		object_ref.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		
	if object_ref is CollisionObject3D:
		object_ref.collision_layer = 0
		object_ref.collision_mask = 0

func _process(_delta: float) -> void:
	pass
