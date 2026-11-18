extends Node2D

@onready var pieces = [
	$"Piece 1", $"Piece 2", $"Piece 3", $"Piece 4", 
	$"Piece 5", $"Piece 6", $"Piece 7", $"Piece 8"
]

var piece_states = [0, 0, 0, 0, 0, 0, 0, 0]
var winning_states = [0, 0, 0, 0, 0, 0, 0, 0]

@onready var moves_remaining_label:= $Label
var moves_remaining = 14 # Enough buffer for a 7-step solution
@export var max_moves = 14
var is_shuffling = false 
var is_animating = false 

# A clean, 7-step medium difficulty recipe using strictly 90-degree turns
var medium_recipe = [2, 3, 1, 5, 4, 1]

func _ready() -> void:
	# 1. Capture whatever rotation you set in the editor as the "Solved" state
	for i in range(pieces.size()):
		piece_states[i] = int(round(pieces[i].rotation / (PI / 2))) % 4
	winning_states = piece_states.duplicate()
	
	# 2. Scramble using the fixed recipe on startup
	reset_puzzle()

# Helper function for strictly 90-degree rotations (amount = 1)
func apply_rotation(indices: Array, amount: int = 1, instant: bool = false) -> void:
	if not instant:
		is_animating = true
		
	for i in indices:
		var idx = i - 1
		piece_states[idx] = (piece_states[idx] + amount) % 4
		var target_rotation = piece_states[idx] * (PI / 2)
		
		if instant:
			pieces[idx].rotation = target_rotation
		else:
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(pieces[idx], "rotation", target_rotation, 0.45)
			
	if not instant:
		await get_tree().create_timer(0.45).timeout
		is_animating = false

# Function called by player buttons
func rotate_pieces(indices: Array, amount: int = 1) -> void:
	if moves_remaining <= 0 or is_shuffling or is_animating:
		return
		
	moves_remaining -= 1
	print("Moves left: ", moves_remaining)
	update_moves_label()
	
	await apply_rotation(indices, amount, false)
	
	check_win_condition()
	check_lose_condition()

# Resets the puzzle using the fixed medium recipe (Deterministic & repeatable)
func reset_puzzle() -> void:
	is_shuffling = true
	
	# Reset pieces visually and logically back to the win state first
	for i in range(pieces.size()):
		piece_states[i] = winning_states[i]
		pieces[i].rotation = piece_states[i] * (PI / 2)
	
	# Replay the sequence instantly to build the starting puzzle layout
	for btn_id in medium_recipe:
		execute_button_action_instant(btn_id)
	
	is_shuffling = false
	moves_remaining = max_moves
	update_moves_label()
	print("Puzzle reset to medium difficulty layout.")

# Instant execution version used strictly for scrambling setup (matches player actions 100%)
func execute_button_action_instant(button_id: int) -> void:
	match button_id:
		1: apply_rotation([1, 2, 3], 1, true)
		2: apply_rotation([3, 4, 5], 1, true)
		3: apply_rotation([5, 6, 7], 1, true)
		4: apply_rotation([2, 4, 6], 1, true)
		5: apply_rotation([4, 7, 8], 1, true)

# Central function mapping button IDs to their specific pieces (Now perfectly uniform 90-deg turns)
func execute_button_action(button_id: int) -> void:
	match button_id:
		1: await rotate_pieces([1, 2, 3], 1)
		2: await rotate_pieces([3, 4, 5], 1)
		3: await rotate_pieces([5, 6, 7], 1)
		4: await rotate_pieces([2, 4, 6], 1)
		5: await rotate_pieces([4, 7, 8], 1)

func update_moves_label() -> void:
	if moves_remaining_label:
		moves_remaining_label.text = "Moves remaining: " + str(moves_remaining)

func check_win_condition() -> void:
	if piece_states == winning_states:
		print("Puzzle Solved! Fluid is flowing.")
		moves_remaining = 999 
		if moves_remaining_label:
			moves_remaining_label.text = "Success! Fluid Flowing."

func check_lose_condition() -> void:
	if moves_remaining <= 0 and piece_states != winning_states:
		print("Out of moves! Resetting puzzle...")
		if moves_remaining_label:
			moves_remaining_label.text = "Out of Moves! Resetting..."
			
		await get_tree().create_timer(1.5).timeout
		reset_puzzle()

# --- BUTTON SIGNALS (5 Buttons, Uniform 90-degree shifts) ---

func _on_button_pressed() -> void:
	await execute_button_action(1)

func _on_button_pressed2() -> void:
	await execute_button_action(2)

func _on_button_pressed3() -> void:
	await execute_button_action(3)

func _on_button_pressed4() -> void:
	await execute_button_action(4)

func _on_button_pressed5() -> void:
	await execute_button_action(5)
