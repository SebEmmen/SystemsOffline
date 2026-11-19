class_name Slot
extends Marker2D

var piece: Piece = null

func _ready() -> void:
	add_to_group("slots")

func is_free() -> bool:
	return piece == null
