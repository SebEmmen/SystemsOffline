extends Node3D

@export var rotation_speed: float = 0.005
var is_dragging: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
	elif event is InputEventMouseMotion and is_dragging:
		# Rotate around the Y axis based on horizontal mouse movement
		rotate_y(-event.relative.x * rotation_speed)
		
		# Clamp rotation if you want a limited range (e.g., -140 to 140 degrees)
		rotation.y = clamp(rotation.y, deg_to_rad(-140), deg_to_rad(140))
