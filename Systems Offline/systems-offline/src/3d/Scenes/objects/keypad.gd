extends Node3D

@onready var screen_label: Label3D = $Screen
@export var sliding_door: StaticBody3D

var entered_code := ""
var correct_code := "51515"

func _ready() -> void:
	update_screen()

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
	else:
		print("Wrong code!")
		entered_code = ""

	update_screen()
