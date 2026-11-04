extends Node3D

@onready var brown_screen: Node3D = $"Final_Screen on and off/Brown_screen"

var is_activated: bool = false


func interact() -> void:
	if is_activated:
		return

	is_activated = true
	brown_screen.hide()

	print("Screen turned on!")
