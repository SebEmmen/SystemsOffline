extends Node3D

@onready var screen_label: Label3D = $Screen
@export var sliding_door: StaticBody3D
@onready var lock_led: MeshInstance3D = $LockLED

var entered_code := ""
var correct_code := "51515"

func _ready() -> void:
	update_screen()
	update_led(true)

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
		sliding_door.unlock()
		flash_enter()
		update_led(false)
	else:
		print("Wrong code!")
		entered_code = ""
		update_screen()
	
	
func flash_enter():
	screen_label.text = "ENTER"
	screen_label.modulate = Color("00c700")

	await get_tree().create_timer(1.0).timeout
	screen_label.modulate = Color("ffffff")
	screen_label.text = correct_code
	
	
	
func update_led(locked: bool) -> void:
	var material := lock_led.get_active_material(0) as StandardMaterial3D

	if locked:
		material.albedo_color = Color.RED
		material.emission = Color.RED
	else:
		material.albedo_color = Color.GREEN
		material.emission = Color.GREEN
