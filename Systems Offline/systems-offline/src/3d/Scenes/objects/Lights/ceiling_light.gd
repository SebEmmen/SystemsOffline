
extends Node3D

@export_category("Flicker")
@export var flicker_enabled: bool = true
@export var base_energy: float = 2.0
@export var flicker_amount: float = 0.2
@export var flicker_speed: float = 15.0

@onready var light: OmniLight3D = $OmniLight3D

var time: float = 0.0


func _process(delta: float) -> void:
	if not flicker_enabled:
		return

	time += delta * flicker_speed

	var flicker := sin(time) * flicker_amount

	light.light_energy = base_energy + flicker
