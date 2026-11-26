extends PanelContainer

var puzzle
var bird_name: String = ""
var is_placed: bool = false

@onready var icon: TextureRect = $Content/BirdIcon
@onready var name_label: Label = $Content/BirdName


func configure(controller: Control, value: String) -> void:
	puzzle = controller
	bird_name = value
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_placed(false)


func set_placed(value: bool) -> void:
	is_placed = value

	# Status is clear in both text and color, even when already placed.
	name_label.text = ("✓ " if is_placed else "○ ") + bird_name
	name_label.add_theme_color_override(
		"font_color", Color("#99f2c8") if is_placed else Color("#e7f4f8")
	)
	icon.modulate = Color(1, 1, 1, 0.60 if is_placed else 1.0)
	tooltip_text = ("PLACED — drag to move" if is_placed else "NOT PLACED — drag onto the grid")

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#123b33") if is_placed else Color("#142735")
	style.border_color = Color("#42df9d") if is_placed else Color("#36798b")
	style.set_border_width_all(2 if is_placed else 1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if puzzle == null or bird_name.is_empty() or not puzzle.can_drag_bird():
		return null

	var preview: Control = puzzle.create_bird_drag_preview(bird_name)
	if preview == null:
		return null

	# Only the PNG follows the cursor; the label stays in the bar.
	set_drag_preview(preview)
	return {"type": "bird", "bird": bird_name}
