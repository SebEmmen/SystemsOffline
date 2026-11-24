extends Node3D

@onready var green_light: MeshInstance3D = $"Multitool pad/Light green"
@onready var red_light: MeshInstance3D = $"Multitool pad/Light red"


func _ready() -> void:
	set_working(true)


func set_working(working: bool) -> void:
	green_light.visible = working
	red_light.visible = not working
