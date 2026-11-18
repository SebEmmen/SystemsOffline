extends Node2D

@onready var pieces = [
	$"Piece 1", $"Piece 2", $"Piece 3", $"Piece 4", 
	$"Piece 5", $"Piece 6", $"Piece 7", $"Piece 8"
]

var piece_states = [0, 0, 0, 0, 0, 0, 0, 0]
var winning_states = [0, 0, 0, 0, 0, 0, 0, 0]

@onready var moves_remaining_label:= $Label
var moves_remaining = 10 # Gives the player a fair buffer for a 4-step solution
@export var max_moves = 10
var is_shuffling = false 
var is_animating = false 

# A fixed, hand-crafted medium difficulty recipe (4 button presses from solved state)
var medium_recipe = [2, 2, 1, 5, 4, 1, 3]

func _ready() -> void:
	# 1. Capture whatever rotation you set in the editor as the "Solved" state
	for i in range(pieces.size()):
		piece_states[i] = int(round(pieces[i].rotation / (PI / 2))) % 4
	winning_states = piece_states.duplicate()
	
	# 2. Scramble using the fixed recipe on startup
	reset_puzzle()

# Helper function supporting asymmetric rotation amounts per piece
func apply_rotation(indices: Array, amounts, instant: bool = false) -> void:
	if not instant:
		is_animating = true
	#moves_remaining -= 1
	print("Moves left: ", moves_remaining)
	update_moves_label()
	for idx_i in range(indices.size()):
		var i = indices[idx_i]
		var idx = i - 1
		
		var rot_amount = 1
		if typeof(amounts) == TYPE_ARRAY:
			rot_amount = amounts[idx_i]
		else:
			rot_amount = amounts
			
		piece_states[idx] = (piece_states[idx] + rot_amount) % 4
		var target_rotation = piece_states[idx] * (PI / 2)
		
		if instant:
			pieces[idx].rotation = target_rotation
		else:
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(pieces[idx], "rotation", target_rotation, 1.0)
			
	if not instant:
		await get_tree().create_timer(1.0).timeout
		is_animating = false

# Function called by player buttons
func rotate_pieces(indices: Array, amounts) -> void:
	if moves_remaining <= 0 or is_shuffling or is_animating:
		return
		
	await apply_rotation(indices, amounts, false)
	
	
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

# Instant execution version used strictly for scrambling setup
func execute_button_action_instant(button_id: int) -> void:
	match button_id:
		1: apply_rotation([1, 3, 5], 1, true)
		2: apply_rotation([2, 4, 6], [1, 2, 1], true)
		3: apply_rotation([3, 4, 7], 1, true)
		4: apply_rotation([5, 6], [1, 1, 1], true)
		5: apply_rotation([7, 8], 1, true)

# Central function mapping button IDs to their specific pieces (Max 3 pieces each)
func execute_button_action(button_id: int) -> void:
	match button_id:
		1: await apply_rotation([1, 3, 5], 1, false)
		2: await apply_rotation([2, 4, 6], [1, 2, 1], false)
		3: await apply_rotation([3, 4, 7], 1, false)
		4: await apply_rotation([5, 7], [1, 1, 1], false)
		5: await apply_rotation([6, 8], 1, false)

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

# --- BUTTON SIGNALS (5 Buttons, Max 3 Pieces Each) ---

func _on_button_pressed() -> void:
	await execute_button_action(1)
	check_win_condition()
	check_lose_condition()

func _on_button_pressed2() -> void:
	await execute_button_action(2)
	check_win_condition()
	check_lose_condition()

func _on_button_pressed3() -> void:
	await execute_button_action(3)
	check_win_condition()
	check_lose_condition()

func _on_button_pressed4() -> void:
	await execute_button_action(4)
	check_win_condition()
	check_lose_condition()

func _on_button_pressed5() -> void:
	await execute_button_action(5)
	check_win_condition()
	check_lose_condition()
