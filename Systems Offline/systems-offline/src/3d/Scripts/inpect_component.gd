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

#region Poster Variable
@export_group("Poster")
var default_font: Font = ThemeDB.fallback_font
@export var alien_language: Font = preload("res://src/2d/Fonts/Systems-Offline (2).ttf")
@export var poster_text: Label3D
#endregion

#region Crate Variables
@export_group("Crate")
@export var number_label: Label3D
@export var number : String = "0"
@export var crate_lid: Node3D
@export var lid_target: Marker3D

@onready var lid_position: Vector3 
@onready var lid_rotation: Vector3
@onready var open:= false


var lid_animating: bool = false
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	match inspect_type:
		InspectType.POSTER:
			pass
		InspectType.CRATE:
			ready_crate()


func interact() -> void:
	match inspect_type:
		InspectType.POSTER:
			enter_inspect()

		InspectType.CRATE:
			if is_interacting or is_transitioning:
				return

			if not open and not lid_animating:
				open_crate()
			else:
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

	# Hide mouse AFTER disabling controls
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	await get_tree().process_frame
	await transition(player_camera, inspect_camera)


func exit_inspect() -> void:
	if not is_interacting or is_transitioning:
		return


	await transition(inspect_camera, player_camera)
	player.visible = true

	is_interacting = false

	await get_tree().process_frame
	player.enable_controls()
	
	


func get_interaction_message() -> String:
	match inspect_type:
		InspectType.CRATE:
			if not open and not lid_animating:
				return "Press [E] to move"
			return "Press [E] to interact"

		InspectType.POSTER:
			return "Press [E] to interact"

	return "Press [E] to interact"



#endregion

#region Crate Functions

func ready_crate() -> void:
	if number_label:
		number_label.text = number
	elif inspect_type == InspectType.CRATE:
		push_warning("InspectComponent: 'number_label' is not assigned on " + name)
		
	if crate_lid:
		lid_position = crate_lid.position
		lid_rotation = crate_lid.rotation
	elif inspect_type == InspectType.CRATE:
		push_warning("InspectComponent: 'crate_lid' is not assigned on " + name)

func place_lid_next() -> void:
	if crate_lid == null or lid_target == null:
		return

	var tween_lid := create_tween()
	tween_lid.set_parallel(true)

	tween_lid.tween_property(
		crate_lid,
		"global_position",
		lid_target.global_position,
		0.5
	)

	tween_lid.tween_property(
		crate_lid,
		"global_rotation",
		lid_target.global_rotation,
		0.5
	)

	await tween_lid.finished




func enter_crate() -> void:
	if not open and not lid_animating:
		return

	if is_interacting or is_transitioning:
		return

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	await enter_inspect()


	


func exit_crate() -> void:
	if not is_interacting or is_transitioning:
		return

	await exit_inspect()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func open_crate() -> void:
	if open or lid_animating:
		return

	if crate_lid == null or lid_target == null:
		return

	lid_animating = true

	# Position tween: X first, then Y.
	var position_tween := create_tween()
	position_tween.set_trans(Tween.TRANS_QUAD)
	position_tween.set_ease(Tween.EASE_IN_OUT)

	position_tween.tween_property(
		crate_lid,
		"position:x",
		lid_target.position.x,
		0.5
	)

	position_tween.tween_property(
		crate_lid,
		"position:y",
		lid_target.position.y,
		0.9
	)


	var rotation_tween := create_tween()

	rotation_tween.set_trans(Tween.TRANS_QUINT)
	rotation_tween.set_ease(Tween.EASE_IN_OUT)

	rotation_tween.tween_property(
		crate_lid,
		"rotation",
		lid_target.rotation,
		1.4
	)

	await position_tween.finished
	await rotation_tween.finished

	open = true
	lid_animating = false


#endregion

#region Poster Functions
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Swap to custom font when player steps into Area3D
		poster_text.font = default_font


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Swap to custom font when player steps into Area3D
		poster_text.font = alien_language
#endregion

func _unhandled_input(event: InputEvent) -> void:
	if not is_interacting or is_transitioning:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		
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
