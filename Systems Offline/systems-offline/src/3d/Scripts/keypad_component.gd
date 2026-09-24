class_name KeypadComponent
extends InteractableComponent

enum KeypadType{
	BUTTON_KEYPAD
}

@export var keypad_type: KeypadType

#region KeyPad Specific Variables
@export_group("KeyPad")
@export var screen_label: Label3D
@export var keypad_camera: Camera3D
@export var sliding_door: Node3D
@export var lock_led: MeshInstance3D
var entered_code := ""
@export var correct_code : String
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	match keypad_type:
		KeypadType.BUTTON_KEYPAD:
			ready_button_keypad()

func interact() -> void:
	match keypad_type:
		KeypadType.BUTTON_KEYPAD:
			object_ref.enter_button_keypad()


#region Button_KeyPad Functions
func ready_button_keypad() -> void:
	update_screen()
	update_led()

func enter_button_keypad() -> void:
	if is_interacting or is_transitioning:
		return
	if !Inventory.has_item("7"):
		print("You need to find the key to access the keypad!")
		return
	
	is_interacting = true

	player.disable_controls()

	player.visible = false
	await transition(player_camera, keypad_camera)


func exit_button_keypad() -> void:
	if not is_interacting or is_transitioning:
		return

	is_interacting = false

	player.enable_controls()

	await transition(keypad_camera, player_camera)
	player.visible = true



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
	var empty_slots := correct_code.length() - entered_code.length()
	screen_label.text = "-".repeat(empty_slots) + entered_code

func check_code() -> void:
	if entered_code == correct_code:
		print("Correct code!")
		sliding_door.unlock_door()
		flash_enter()
		sliding_door.locked = false
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

	if sliding_door.locked:
		material.albedo_color = Color.RED
		material.emission = Color.RED
	else:
		material.albedo_color = Color.GREEN
		material.emission = Color.GREEN
#endregion


func _unhandled_input(event: InputEvent) -> void:
	if not is_interacting or is_transitioning:
		return

	if event.is_action_pressed("ui_cancel"):
		
		match interaction_type:
			InteractionType.KEYPAD:
				exit_button_keypad()
				get_viewport().set_input_as_handled()
		
		return
	# Mouse clicking is only needed for keypad
	if interaction_type == InteractionType.KEYPAD:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				click_keypad_button()
				get_viewport().set_input_as_handled()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
