extends Control

signal puzzle_solved

# Bird names shown to the player. Node names avoid spaces.
const BIRDS := ["Albatross", "Blue Jay", "Cardinal", "Dove", "Eagle", "Flamingo"]
const TOKEN_NODES := {
	"Albatross": "Bird_Albatross",
	"Blue Jay": "Bird_BlueJay",
	"Cardinal": "Bird_Cardinal",
	"Dove": "Bird_Dove",
	"Eagle": "Bird_Eagle",
	"Flamingo": "Bird_Flamingo"
}

# Original 6x6 grid. ONLY X is unplaceable.
const SYMBOLS := [
	["CAGE", "TABLE", "", "X", "", "TREE"],
	["", "X", "TABLE", "", "", ""],
	["X", "", "", "BED", "TREE", ""],
	["", "BED", "X", "", "", "TREE"],
	["", "", "TREE", "X", "", ""],
	["BED", "", "", "", "CAGE", ""]
]

# Vector2i(column, row), zero-based. Same intended solution,
# with Buzzard renamed to Blue Jay and Canary to Cardinal.
const SOLUTION := {
	"Albatross": Vector2i(3, 2),  # D3
	"Blue Jay": Vector2i(2, 1),   # C2
	"Cardinal": Vector2i(4, 5),   # E6
	"Dove": Vector2i(5, 3),       # F4
	"Eagle": Vector2i(0, 0),      # A1
	"Flamingo": Vector2i(1, 4)    # B5
}

@onready var grid: GridContainer = $MainPanel/MainLayout/BoardSection/BoardArea/Grid
@onready var selection: HFlowContainer = $MainPanel/MainLayout/BoardSection/BirdSelection
@onready var feedback: Label = $MainPanel/MainLayout/SidePanel/FeedbackLabel
@onready var check_button: Button = $MainPanel/MainLayout/SidePanel/CheckButton
@onready var reset_button: Button = $MainPanel/MainLayout/SidePanel/ResetButton
@onready var main_panel: PanelContainer = $MainPanel

# Maps bird name -> Vector2i(column, row).
var bird_positions: Dictionary = {}
var solved: bool = false


func _ready() -> void:
	call_deferred("_fit_puzzle_to_screen")
	get_viewport().size_changed.connect(_fit_puzzle_to_screen)
	for row in range(6):
		for col in range(6):
			var cell = get_cell(row, col)
			cell.configure(self, row, col, SYMBOLS[row][col])

	for bird in BIRDS:
		var token = selection.get_node_or_null(TOKEN_NODES[bird])
		if token == null:
			push_error("Bird Matrix: Missing token %s. Run the update installer." % TOKEN_NODES[bird])
			continue
		token.configure(self, bird)

	check_button.pressed.connect(_on_check_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	_update_token_status()
	_show_feedback("Drag birds onto any cell except X. Check when you're ready.")



func get_cell(row: int, col: int) -> Control:
	return grid.get_node("Cell_R%d_C%d" % [row + 1, col + 1]) as Control


func get_bird_texture(bird: String) -> Texture2D:
	if not TOKEN_NODES.has(bird):
		return null
	var token = selection.get_node_or_null(TOKEN_NODES[bird])
	if token == null:
		return null
	var icon := token.get_node_or_null("Content/BirdIcon") as TextureRect
	if icon == null:
		return null
	return icon.texture




func create_bird_drag_preview(bird: String) -> Control:
	var texture := get_bird_texture(bird)
	if texture == null:
		return null

	# Change this to control the PNG size.
	var preview_size := Vector2(60, 60)

	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture = texture

	# Prevent the original PNG dimensions from setting a minimum size.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	icon.custom_minimum_size = Vector2.ZERO
	icon.size = preview_size

	# Center the PNG on the mouse.
	icon.position = -preview_size / 2.0

	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	preview.add_child(icon)

	return preview




func can_drag_bird() -> bool:
	return not solved


func can_place_bird(bird: String, row: int, col: int) -> bool:
	if solved or not BIRDS.has(bird):
		return false
	if row < 0 or row >= 6 or col < 0 or col >= 6:
		return false
	# No row/column restrictions while placing: mistakes are allowed.
	return SYMBOLS[row][col] != "X"


func place_bird(bird: String, row: int, col: int) -> void:
	if not can_place_bird(bird, row, col):
		return

	var target = get_cell(row, col)
	if target.bird == bird:
		return

	# If this cell is occupied, send its old bird back to the tray.
	var displaced_bird: String = target.bird
	if not displaced_bird.is_empty():
		bird_positions.erase(displaced_bird)
		target.set_bird("")

	# A single bird cannot occupy two cells simultaneously.
	if bird_positions.has(bird):
		var previous: Vector2i = bird_positions[bird]
		get_cell(previous.y, previous.x).set_bird("")

	bird_positions[bird] = Vector2i(col, row)
	target.set_bird(bird)
	_update_token_status()

	var message := "%s placed at %s%d (%d/6)." % [bird, char(65 + col), row + 1, bird_positions.size()]
	if not displaced_bird.is_empty():
		message += " %s returned to the bird bar." % displaced_bird
	_show_feedback(message)


func _fit_puzzle_to_screen() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := main_panel.get_combined_minimum_size()

	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return

	var padding := 30.0
	var available_size := viewport_size - Vector2.ONE * padding * 2.0

	var scale_factor: float = minf(
		1.0,
		minf(
			available_size.x / panel_size.x,
			available_size.y / panel_size.y
		)
	)

	main_panel.scale = Vector2.ONE * scale_factor
	main_panel.position = (viewport_size - panel_size * scale_factor) / 2.0

func _update_token_status() -> void:
	for bird in BIRDS:
		var token = selection.get_node_or_null(TOKEN_NODES[bird])
		if token != null:
			token.set_placed(bird_positions.has(bird))


func _on_reset_pressed() -> void:
	for bird in bird_positions:
		var pos: Vector2i = bird_positions[bird]
		get_cell(pos.y, pos.x).set_bird("")
	bird_positions.clear()
	solved = false
	check_button.disabled = false
	_update_token_status()
	_show_feedback("All birds returned to the bird bar.")


func _on_check_pressed() -> void:
	if solved:
		return
	if bird_positions.size() != BIRDS.size():
		_show_feedback("Place all six birds before checking.")
		return

	# The grid deliberately allows incorrect rows and columns.
	# Only the Check button evaluates the final solution.
	for bird in BIRDS:
		if not bird_positions.has(bird) or bird_positions[bird] != SOLUTION[bird]:
			_show_feedback("Incorrect solution. Check the clues and try again!")
			return

	solved = true
	check_button.disabled = true
	_show_feedback("SUCCESS! All birds are in the correct positions!")
	puzzle_solved.emit()


func _show_feedback(message: String) -> void:
	feedback.text = message
