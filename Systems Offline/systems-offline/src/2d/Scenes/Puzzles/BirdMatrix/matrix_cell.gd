extends PanelContainer

var puzzle
var row_index: int = 0
var column_index: int = 0
var base_symbol: String = ""
var bird: String = ""

@onready var location_icon: TextureRect = $CellContent/LocationIcon
@onready var blocked_icon: TextureRect = $CellContent/BlockedIcon
@onready var placed_icon: TextureRect = $CellContent/PlacedBird
@onready var placeholder: Label = $CellContent/Placeholder


func configure(controller: Control, row: int, col: int, symbol: String) -> void:
	puzzle = controller
	row_index = row
	column_index = col
	base_symbol = symbol
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


func set_bird(value: String) -> void:
	bird = value
	_refresh()


func _refresh() -> void:
	var occupied := not bird.is_empty()
	var blocked := base_symbol == "⦸"

	# Keep the LocationIcon textures you already set in every cell.
	location_icon.visible = location_icon.texture != null
	location_icon.modulate = Color(1, 1, 1, 0.20 if occupied else 1.0)
	blocked_icon.visible = (
		blocked
		and blocked_icon.texture != null
		and placeholder.text.is_empty()
	)

	# Show bird PNG over the faded location icon, never the bird name.
	placed_icon.visible = occupied
	placed_icon.texture = puzzle.get_bird_texture(bird) if occupied and puzzle != null else null
	placed_icon.custom_minimum_size = Vector2(54, 54)
	placed_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	placed_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Only fall back to textual location symbols if no icons were assigned.
	placeholder.visible = (
		not occupied
		and not location_icon.visible
		and not blocked_icon.visible
		and not placeholder.text.is_empty()
	)

	var description := bird if occupied else (base_symbol if not base_symbol.is_empty() else "empty")
	tooltip_text = "Row %d, column %s: %s" % [row_index + 1, char(65 + column_index), description]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if bird.is_empty() or puzzle == null or not puzzle.can_drag_bird():
		return null

	var preview: Control = puzzle.create_bird_drag_preview(bird)
	if preview == null:
		return null

	set_drag_preview(preview)
	return {"type": "bird", "bird": bird}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if puzzle == null or not data is Dictionary:
		return false
	if data.get("type", "") != "bird":
		return false
	# Only X is blocked. Occupied cells and matching rows/columns are okay.
	return puzzle.can_place_bird(str(data.get("bird", "")), row_index, column_index)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	puzzle.place_bird(str(data.get("bird", "")), row_index, column_index)
