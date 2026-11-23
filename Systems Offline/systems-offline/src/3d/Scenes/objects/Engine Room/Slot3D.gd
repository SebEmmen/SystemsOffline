class_name Slot3D
extends Marker3D

var piece: Piece3D = null

func _ready() -> void:
	add_to_group("slots")

func is_free() -> bool:
	return piece == null
