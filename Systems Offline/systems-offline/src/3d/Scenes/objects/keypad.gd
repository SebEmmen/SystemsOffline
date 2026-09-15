extends Node3D

@onready var screen_label: Label3D = $Screen
@onready var lock_led: MeshInstance3D = $LockLED
@onready var keypad_camera: Camera3D = $KeypadCamera

@export var sliding_door: Node3D
@export var player: CharacterBody3D
@export var player_camera: Camera3D

var entered_code := ""
var correct_code := "51515"
var using_keypad := false
var hovered_button: Object = null


func _ready() -> void:
	update_screen()
	update_led(true)

func _process(_delta: float) -> void:
	if not using_keypad:
		return

	var new_hovered_button := get_button_under_mouse()

	if new_hovered_button == hovered_button:
		return

	if hovered_button != null and hovered_button.has_method("set_hovered"):
		hovered_button.set_hovered(false)

	hovered_button = new_hovered_button

	if hovered_button != null and hovered_button.has_method("set_hovered"):
		hovered_button.set_hovered(true)

func press_key(key: String) -> void:
	if key == "C":
		entered_code = ""

	elif key == "OK":
		check_code()

	elif entered_code.length() < 5:
		entered_code += key

	update_screen()


func update_screen() -> void:
	var empty_slots := 5 - entered_code.length()
	screen_label.text = "-".repeat(empty_slots) + entered_code


func check_code() -> void:
	if entered_code == correct_code:
		print("Correct code!")
		sliding_door.unlock()
		update_led(false)
	else:
		print("Wrong code!")
		entered_code = ""

	update_screen()


func update_led(locked: bool) -> void:
	var material := lock_led.get_active_material(0) as StandardMaterial3D

	if locked:
		material.albedo_color = Color.RED
		material.emission = Color.RED
	else:
		material.albedo_color = Color.GREEN
		material.emission = Color.GREEN


func enter_keypad() -> void:
	if using_keypad:
		return

	using_keypad = true

	keypad_camera.make_current()
	player.disable_controls()


func exit_keypad() -> void:
	using_keypad = false

	player_camera.make_current()

	# Wait until the Escape input has finished processing.
	await get_tree().process_frame

	player.enable_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not using_keypad:
		return

	# Leave keypad with Escape
	if event.is_action_pressed("ui_cancel"):
		exit_keypad()
		get_viewport().set_input_as_handled()

	# Click keypad buttons with left mouse button
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			click_keypad_button()
			get_viewport().set_input_as_handled()

func get_button_under_mouse() -> Object:
	var mouse_position := get_viewport().get_mouse_position()

	var ray_origin := keypad_camera.project_ray_origin(mouse_position)
	var ray_direction := keypad_camera.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * 5.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)

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
