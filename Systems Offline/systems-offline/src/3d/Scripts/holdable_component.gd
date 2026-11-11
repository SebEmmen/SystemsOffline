class_name HoldableInteractableComponent
extends InteractableComponent

@export_group("Shader Glow Effect")
@export var enable_glow: bool = true
@export var glow_color: Color = Color(0.851, 0.574, 0.095, 1.0) # Warm golden glow
@export var glow_energy: float = 3.0 # Intensity of the emission glow

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
		
	play_primary_se()
	
	# Turn OFF the glow effect the moment it's picked up
	set_object_glow(false)
	
	active_player = get_tree().get_first_node_in_group("player")
	if not active_player:
		printerr("HoldableInteractableComponent: No node found in 'player' group!")
		return
		
	if "hand_marker" in active_player and active_player.hand_marker:
		active_hand_marker = active_player.hand_marker
	else:
		printerr("HoldableInteractableComponent: ProtoController is missing its hand_marker export reference!")
		return

	if "current_held_item" in active_player:
		if active_player.current_held_item and active_player.current_held_item != self:
			active_player.current_held_item.drop_item()
		active_player.current_held_item = self

	var current_parent = object_ref.get_parent()
	if current_parent:
		current_parent.remove_child(object_ref)
		
	active_hand_marker.add_child(object_ref)
	
	reset_position()
	disable_physics()
	is_held = true
	
	print("Successfully picked up item!")

func drop_item() -> void:
	if not is_held:
		return
		
	var world_root = get_tree().current_scene
	object_ref.reparent(world_root, true)
	
	if active_player:
		var drop_dir = -active_player.global_transform.basis.z
		if "camera" in active_player and active_player.camera:
			drop_dir = -active_player.camera.global_transform.basis.z
			drop_dir.y = 0.0 # Keep it flat on the ground plane
			drop_dir = drop_dir.normalized()
			
			if drop_dir == Vector3.ZERO:
				drop_dir = -active_player.global_transform.basis.z

		var target_drop_pos = active_player.global_position + (drop_dir * 1.0)

		# BRANCH 1: RigidBody3D physics drop
		if object_ref is RigidBody3D:
			object_ref.freeze = false
			object_ref.collision_layer = original_collision_layer
			object_ref.collision_mask = original_collision_mask
			object_ref.global_position = target_drop_pos + Vector3(0, 0.8, 0)
			object_ref.linear_velocity = drop_dir * 1.0
			
		# BRANCH 2: Static / Non-rigidbody drop with ground snapping & height correction
		else:
			if object_ref is CollisionObject3D:
				object_ref.collision_layer = original_collision_layer
				object_ref.collision_mask = original_collision_mask
			
			var space_state = object_ref.get_world_3d().direct_space_state
			var ray_start = target_drop_pos + Vector3(0, 1.5, 0)
			var ray_end = target_drop_pos - Vector3(0, 2.0, 0)
			
			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			var result = space_state.intersect_ray(query)
			
			if result:
				object_ref.global_position = result.position
				
				var local_aabb = get_object_aabb(object_ref)
				if local_aabb.has_volume():
					var bottom_y_offset = -local_aabb.position.y
					object_ref.global_position.y += bottom_y_offset
				else:
					object_ref.global_position.y += 0.05
			else:
				object_ref.global_position = target_drop_pos + Vector3(0, 0.2, 0)
			
	# Turn ON the emission glow effect when dropped!
	if enable_glow:
		set_object_glow(true)
			
	is_held = false
	active_player = null
	active_hand_marker = null
	print("Item dropped with emission glow active!")

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
