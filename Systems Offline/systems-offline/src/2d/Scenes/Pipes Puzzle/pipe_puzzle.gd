extends Node2D

@onready var grid_spots = [
	$"Grid 1x2", $"Grid 2x2", $"Grid 2x3", $"Grid 3x1",
	$"Grid 3x2", $"Grid 3x3", $"Grid 4x2", $"Grid 4x3"
]

@onready var moves_remaining_label:= $Label
var moves_remaining = 5 # Enough buffer for a 7-step solution
@export var max_moves = 5
var is_shuffling = false 
var is_animating = false 

# A clean, 7-step medium difficulty recipe using strictly 90-degree turns
var medium_recipe = [2, 3, 1, 5, 4, 1]

func _ready() -> void:
	# 2. Scramble using the fixed recipe on startup
	pass
func update_moves_label() -> void:
	if moves_remaining_label:
		moves_remaining_label.text = "Moves remaining: " + str(moves_remaining)

func rotate_grid_180(slot: int) -> void:
	grid_spots[slot-1].rotate(1.5708*2)

func rotate_grid_90(slot: int) -> void:
	grid_spots[slot-1].rotate(1.5708)
	
func rotate_grid_neg90(slot: int) -> void:
	grid_spots[slot-1].rotate(1.5708*-1)

func _on_button_pressed() -> void:
	rotate_grid_180(5)

func _on_button_pressed2() -> void:
	rotate_grid_90(3)
	rotate_grid_90(7)

func _on_button_pressed3() -> void:
	rotate_grid_90(1)
	rotate_grid_90(8)
