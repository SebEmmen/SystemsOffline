class_name InteractableComponent
extends Node

enum InteractionType{
	DEFAULT,
	INSPECT,
	DOOR,
	KEYPAD,
	KNOB
}

# Select specific object reference and interaction type (set to default)
@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
@export var player: CharacterBody3D
@export var player_camera: Camera3D
@export var transition_camera: Camera3D

#region Default Variables
@export_group("Default")
var can_interact: bool = true
var is_interacting: bool = false 
var is_transitioning := false
#endregion
#region Inspect Variables
@export_group("Inspect")
@export var inspect_camera : Camera3D
#endregion
#region Door Specific Variables
@export_group("Door")
@onready var default_position: Vector3 = object_ref.position
@export var locked: bool = true
#endregion
#region KeyPad Specific Variables
@export_group("KeyPad")
@export var screen_label: Label3D
@export var keypad_camera: Camera3D
@export var sliding_door: Node3D
@export var lock_led: MeshInstance3D
var entered_code := ""
@export var correct_code : String
#endregion
#region Knob Specific Variables
@export_group("Knob")
@export var rotation_speed : float = 0.05
#endregion
#region Sound Effects Variables
@export_group("Sound Effects")
var primary_audio_player: AudioStreamPlayer3D
var secondary_audio_player: AudioStreamPlayer3D
var tertiary_audio_player: AudioStreamPlayer3D

@export var primary_se: AudioStream
@export var secondary_se: AudioStream
@export var tertiary_se: AudioStream
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	match interaction_type:
		InteractionType.DEFAULT:
			pass
		InteractionType.KEYPAD:
			ready_keypad()

func interact() -> void:
	match interaction_type:
		InteractionType.DEFAULT: 
			print("Object has been picked up!")
			queue_free()
			object_ref.visible = false
		InteractionType.INSPECT:
			interact_inspect()
		InteractionType.DOOR:
			interact_door()
		InteractionType.KEYPAD:
			interact_keypad()

func transition(from: Camera3D, target: Camera3D) -> void:
	if is_transitioning:
		return

	is_transitioning = true

	transition_camera.global_transform = from.global_transform
	transition_camera.make_current()

	# Create the tween
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		transition_camera,
		"global_transform",
		target.global_transform,
		0.5
	)

	await tween.finished

	# Target camera takes over
	target.make_current()

	is_transitioning = false


#region Door Functions

# Interact Function for Door
func interact_door() -> void:
	if locked:
		print("Door is locked!")
		return
	if can_interact:
		can_interact = false
		is_interacting = !is_interacting
	var tween_door = create_tween()
	var target_pos = default_position + Vector3(3.4, 0, 0)
	if is_interacting:
		tween_door.tween_property(object_ref, "position", target_pos, 1.0)
	else:
		tween_door.tween_property(object_ref, "position", default_position, 1.0)

		await tween_door.finished
	can_interact = true

# Unlocks the door
func unlock_door() -> void:
	locked = false
	print("Door unlocked!")
	
#endregion


#region KeyPad Functions
func ready_keypad() -> void:
	update_screen()
	update_led()

func interact_keypad() -> void:
	object_ref.enter_keypad()

func enter_keypad() -> void:
	if is_interacting or is_transitioning:
		return

	is_interacting = true

	player.disable_controls()

	player.visible = false
	await transition(player_camera, keypad_camera)


func exit_keypad() -> void:
	if not is_interacting or is_transitioning:
		return

	is_interacting = false

	player.enable_controls()

	await transition(keypad_camera, player_camera)
	player.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_interacting or is_transitioning:
		return

	if event.is_action_pressed("ui_cancel"):
		
		match interaction_type:
			InteractionType.KEYPAD:
				exit_keypad()
				get_viewport().set_input_as_handled()

			InteractionType.INSPECT:
				exit_inspect()
				get_viewport().set_input_as_handled()
		
		return
	# Mouse clicking is only needed for keypad
	if interaction_type == InteractionType.KEYPAD:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				click_keypad_button()
				get_viewport().set_input_as_handled()

func get_button_under_mouse() -> Object:
	var mouse_position := get_viewport().get_mouse_position()

	var ray_origin := keypad_camera.project_ray_origin(mouse_position)
	var ray_direction := keypad_camera.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * 5.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result : Dictionary = keypad_camera.get_world_3d().direct_space_state.intersect_ray(query)

	if result:
		return result.collider

	return null

func click_keypad_button() -> void:
	var button := get_button_under_mouse()

	if button == null:
		return

	print("Mouse hit: ", button.name)

	if button.has_method("interact"):
		button.interact()

func press_key(key: String) -> void:
	if key == "C":
		entered_code = ""

	elif key == "OK":
		check_code()
		return

	elif entered_code.length() < 5:
		entered_code += key

	update_screen()

func update_screen() -> void:
	var empty_slots := 5 - entered_code.length()
	screen_label.text = "-".repeat(empty_slots) + entered_code

func check_code() -> void:
	if entered_code == correct_code:
		print("Correct code!")
		sliding_door.unlock_door()
		flash_enter()
		locked = false
		update_led()
	else:
		flash_error()
		#entered_code = ""
		#update_screen()
	
	
func flash_enter():
	screen_label.text = "ENTER"
	screen_label.modulate = Color("00c700")

	await get_tree().create_timer(1.0).timeout
	screen_label.modulate = Color("ffffff")
	screen_label.text = correct_code
	
func flash_error():
	screen_label.text = "ERROR"
	screen_label.modulate = Color("f00000ff")
	
	await get_tree().create_timer(1.0).timeout
	screen_label.modulate = Color("ffffff")
	screen_label.text = entered_code
	
func update_led() -> void:
	var material := lock_led.get_active_material(0) as StandardMaterial3D

	if locked:
		material.albedo_color = Color.RED
		material.emission = Color.RED
	else:
		material.albedo_color = Color.GREEN
		material.emission = Color.GREEN
#endregion


#region Inspect Functions

func interact_inspect() -> void:
	object_ref.enter_inspect()

func enter_inspect() -> void:
	if is_interacting or is_transitioning:
		return

	is_interacting = true

	player.disable_controls()

	await transition(player_camera, inspect_camera)

	player.visible = false
	
func exit_inspect() -> void:
	if not is_interacting or is_transitioning:
		return

	player.visible = true

	await transition(inspect_camera, player_camera)

	is_interacting = false

	await get_tree().process_frame
	player.enable_controls()
	

#endregion
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
