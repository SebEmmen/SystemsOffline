class_name InspectComponent
extends InteractableComponent


enum InspectType{
	POSTER,
	CRATE
	}
	
@export var inspect_type: InspectType
#region Inspect Variables
@export_group("Inspect")
@export var inspect_camera : Camera3D
#endregion

#region Crate Variables
@export_group("Crate")
@export var number_label: Label3D
@export var number : String = "0"
@export var crate_lid: Node3D
@onready var lid_position: Vector3 
@onready var lid_rotation: Vector3
@onready var open:= false
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if number_label:
		number_label.text = number
	elif inspect_type == InspectType.CRATE:
		push_warning("InspectComponent: 'number_label' is not assigned on " + name)
		
	if crate_lid:
		lid_position = crate_lid.position
		lid_rotation = crate_lid.rotation
	elif inspect_type == InspectType.CRATE:
		push_warning("InspectComponent: 'crate_lid' is not assigned on " + name)

func interact() -> void:
	match inspect_type:
		InspectType.POSTER:
			enter_inspect()
		InspectType.CRATE:
			enter_crate()

#region Inspect Functions

#func interact_inspect() -> void:
	#object_ref.enter_inspect()

func enter_inspect() -> void:
	if is_interacting or is_transitioning:
		return

	is_interacting = true

	player.disable_controls()

	player.visible = false
	await transition(player_camera, inspect_camera)

func exit_inspect() -> void:
	if not is_interacting or is_transitioning:
		return

	player.visible = true

	await transition(inspect_camera, player_camera)

	is_interacting = false

	await get_tree().process_frame
	player.enable_controls()
	

#endregion

#region Crate Functions
func move_lid() -> void:
	var tween_lid := create_tween()
	var final_pos = lid_position + Vector3(-0.5, 0.0, 0.0)
	if !open:
		tween_lid.tween_property(crate_lid, "position", final_pos, 1.0)
		open = !open
	else:
		tween_lid.tween_property(crate_lid, "position", lid_position, 1.0)
		open = !open

func place_lid_next() -> void:
	var tween_lid := create_tween()
	var final_pos = lid_position + Vector3(-1.43, 0.0, 0.0)
	tween_lid.tween_property(crate_lid, "position",final_pos, 0.4)
	tween_lid.tween_property(crate_lid, "rotation", Vector3(0.0, 0.0, -200.0), 0.0)
	tween_lid.tween_property(crate_lid, "position", final_pos + Vector3(0.0, -0.65, 0.0), 0.0)


func place_lid_on() -> void:
	var tween_lid := create_tween()
	var final_pos = lid_position + Vector3(-1.43, 0.0, 0.0)
	tween_lid.tween_property(crate_lid, "position", final_pos, 0.0)
	tween_lid.tween_property(crate_lid, "rotation", Vector3(0.0, 0.0, 0.0), 0.0)
	tween_lid.tween_property(crate_lid, "position", lid_position, 0.5)

	

func enter_crate() -> void:
	player.disable_controls()
	move_lid()
	await get_tree().create_timer(1.0).timeout
	enter_inspect()
	crate_lid.visible = false
	place_lid_next()
	crate_lid.visible = true
	

func exit_crate() -> void:
	exit_inspect()
	crate_lid.visible = false
	place_lid_on()
	crate_lid.visible = true
	await get_tree().create_timer(0.5).timeout
	move_lid()
	player.enable_controls()

#endregion

func _unhandled_input(event: InputEvent) -> void:
	if not is_interacting or is_transitioning:
		return
	if event.is_action_pressed("ui_cancel"):
		
		match inspect_type:
			InspectType.CRATE:
				exit_crate()
				get_viewport().set_input_as_handled()
			InspectType.POSTER:
				exit_inspect()
				get_viewport().set_input_as_handled()		
		return
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
