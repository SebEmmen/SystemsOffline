
extends Node3D

@onready var multitool: Node3D = $Multitool
@onready var camera: Camera3D = get_parent() as Camera3D
@onready var player: Node = get_node("../../..")

var has_multitool: bool = false
var is_equipped: bool = false

@export_group("Multitool Upgrades")
@export var upgrades: Array[Node3D]
@export var upgrades_ids: Array[String]


func _ready() -> void:
	#_make_multitool_render_on_top()
	add_to_group("multitool_equipment")

	# Restore ownership from SaveManager.
	has_multitool = SaveManager.is_multitool_part_complete(
        "pickup_multitool"
	)

	is_equipped = false

	_update_visibility()
	_update_upgrades()

	# Disable collisions.
	for node in multitool.find_children(
		"*", "CollisionObject3D", true, false
	):
		var collider := node as CollisionObject3D
		collider.collision_layer = 0
		collider.collision_mask = 0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("equip_multitool"):
		return

	if event is InputEventKey and event.echo:
		return

	if not has_multitool:
		return

	if not camera.current:
		return

	if player.get("controls_enabled") != true:
		return

	# Toggle equipment instantly.
	is_equipped = not is_equipped
	_update_visibility()

	get_viewport().set_input_as_handled()


func _make_multitool_render_on_top() -> void:
	for node in multitool.find_children(
		"*", "MeshInstance3D", true, false
	):
		var mesh_instance := node as MeshInstance3D

		# Handle meshes that already have a material override.
		if mesh_instance.material_override != null:
			if mesh_instance.material_override is BaseMaterial3D:
				var mat := mesh_instance.material_override.duplicate() as BaseMaterial3D
				mat.no_depth_test = true
				mat.render_priority = 100
				mesh_instance.material_override = mat
			continue

		if mesh_instance.mesh == null:
			continue

		for surface in range(mesh_instance.mesh.get_surface_count()):
			var original := mesh_instance.get_active_material(surface)

			if original is BaseMaterial3D:
				var mat := original.duplicate() as BaseMaterial3D

				# Render in front of walls.
				mat.no_depth_test = true
				mat.render_priority = 100

				mesh_instance.set_surface_override_material(
					surface, mat
				)
			elif original is ShaderMaterial:
				push_warning(
					"Custom shader needs depth_test_disabled: "
					+ mesh_instance.name
				)


func collect_multitool() -> void:
	if has_multitool:
		return

	has_multitool = true

	print("Multitool collected! Press 1 to equip.")


func _process(_delta: float) -> void:
	_update_visibility()
	_update_upgrades()


func _update_visibility() -> void:
	var should_show : bool = (
		has_multitool
		and is_equipped
		and camera.current
		and player.get("controls_enabled") == true
	)

	multitool.visible = should_show

	# Show or hide the arm together with the multitool.
	if player.arm:
		player.arm.visible = should_show

func _update_upgrades() -> void:
	var i = 0
	for upgrade in upgrades_ids:
		if SaveManager.is_multitool_part_complete(upgrade):
			upgrades[i].visible = true
			if i < 3:
				i = i+1
	pass
