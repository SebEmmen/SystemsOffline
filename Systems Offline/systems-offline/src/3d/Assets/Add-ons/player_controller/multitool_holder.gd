extends Node3D

@onready var multitool: Node3D = $Multitool
@onready var camera: Camera3D = get_parent() as Camera3D
@onready var player: Node = get_node("../../..")

var has_multitool: bool = false
var is_equipped: bool = false

@export_group("Multitool Upgrades")
@export var upgrades: Array[Node3D]
@export var upgrades_ids: Array[String]
@export var upgrade_inputs: Array[StringName] # Input action names per upgrade (e.g., "comm_ability", "scanner_ability")

# Track materials, tweens, and states individually for each upgrade piece
var upgrade_materials: Array[ShaderMaterial] = []
var upgrade_tweens: Array[Tween] = []
var upgrade_active_states: Array[bool] = []


func _ready() -> void:
	add_to_group("multitool_equipment")

	# Restore ownership from SaveManager.
	has_multitool = SaveManager.is_multitool_part_complete(
		"pickup_multitool"
	)

	is_equipped = false

	# 1. Setup materials FIRST so upgrade_active_states is populated before checking it
	_setup_upgrade_materials()
	
	# 2. Then update visibility and upgrades
	_update_visibility()
	_update_upgrades()

	# Force the first upgrade to be active immediately upon ready if collected
	if upgrades_ids.size() > 0 and SaveManager.is_multitool_part_complete(upgrades_ids[0]):
		_set_upgrade_active(0, true)

	# Disable collisions.
	for node in multitool.find_children(
		"*", "CollisionObject3D", true, false
	):
		var collider := node as CollisionObject3D
		collider.collision_layer = 0
		collider.collision_mask = 0


func _setup_upgrade_materials() -> void:
	upgrade_materials.clear()
	upgrade_tweens.clear()
	upgrade_active_states.clear()
	
	for upgrade in upgrades:
		upgrade_active_states.append(false)
		upgrade_tweens.append(null)
		
		var mat: ShaderMaterial = null
		if upgrade is MeshInstance3D:
			var mesh_inst := upgrade as MeshInstance3D
			var active_mat = mesh_inst.get_active_material(0)
			if active_mat is ShaderMaterial:
				# Duplicate material so each upgrade piece can glow independently
				mat = active_mat.duplicate() as ShaderMaterial
				mesh_inst.set_surface_override_material(0, mat)
		upgrade_materials.append(mat)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not has_multitool:
		return
	if not camera.current:
		return
	if player.get("controls_enabled") != true:
		return

	# 1. Handle traditional equip/unequip toggle key
	if event.is_action_pressed("equip_multitool"):
		is_equipped = not is_equipped
		_update_visibility()
		get_viewport().set_input_as_handled()
		return

	# 2. Handle individual upgrade inputs
	for i in range(upgrade_inputs.size()):
		if i >= upgrades.size():
			break
		
		var action_name = upgrade_inputs[i]
		if action_name != &"" and event.is_action_pressed(action_name):
			# If it's the first upgrade (index 0), it is always on—ignore input toggling!
			if i == 0:
				get_viewport().set_input_as_handled()
				break
			
			# If the multitool isn't equipped yet, bring it up first!
			if not is_equipped:
				is_equipped = true
				_update_visibility()
			
			# Toggle or turn on the glow for other upgrade pieces
			var new_state = not upgrade_active_states[i] if i < upgrade_active_states.size() else true
			_set_upgrade_active(i, new_state)
			
			get_viewport().set_input_as_handled()
			break


func _set_upgrade_active(index: int, active: bool) -> void:
	if index < 0 or index >= upgrades.size():
		return
		
	if index < upgrade_active_states.size():
		upgrade_active_states[index] = active
		
	var mat = upgrade_materials[index] if index < upgrade_materials.size() else null
	
	if index < upgrade_tweens.size() and upgrade_tweens[index] and upgrade_tweens[index].is_running():
		upgrade_tweens[index].kill()
		
	var target_val = 1.0 if active else 0.0
	var start_val = float(mat.get_shader_parameter("activation")) if mat != null else 0.0
	
	if mat != null:
		var tw = create_tween()
		if index < upgrade_tweens.size():
			upgrade_tweens[index] = tw
		tw.tween_method(
			func(val): mat.set_shader_parameter("activation", val),
			start_val,
			target_val,
			0.3 # Duration of light-up fade
		)


func collect_multitool() -> void:
	if has_multitool:
		return

	has_multitool = true
	print("Multitool collected!")


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
	for i in range(upgrades_ids.size()):
		if i >= upgrades.size():
			break
			
		var upgrade_id = upgrades_ids[i]
		if SaveManager.is_multitool_part_complete(upgrade_id):
			upgrades[i].visible = true
			
			# Ensure the first upgrade is always forced on as soon as it's unlocked (with bounds safety)
			if i == 0 and i < upgrade_active_states.size() and not upgrade_active_states[i]:
				_set_upgrade_active(i, true)
		else:
			upgrades[i].visible = false
