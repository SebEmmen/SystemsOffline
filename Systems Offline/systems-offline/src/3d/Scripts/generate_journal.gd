
@tool
extends EditorScript

func _run() -> void:
	var root := CanvasLayer.new()
	root.name = "Journal"

	var ui := Control.new()
	ui.name = "JournalUI"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)

	var overlay := ColorRect.new()
	overlay.name = "DarkOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)

	var book := Control.new()
	book.name = "JournalBook"
	book.custom_minimum_size = Vector2(1100, 700)
	center.add_child(book)

	var background := TextureRect.new()
	background.name = "BookBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	book.add_child(background)

	var left_page := Control.new()
	left_page.name = "LeftPage"
	left_page.position = Vector2(110, 85)
	left_page.size = Vector2(410, 520)
	book.add_child(left_page)

	var left_paper := TextureRect.new()
	left_paper.name = "LeftPaper"
	left_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_page.add_child(left_paper)

	var left_text := TextEdit.new()
	left_text.name = "LeftText"
	left_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	left_text.add_theme_font_size_override("font_size", 22)
	left_page.add_child(left_text)

	var right_page := Control.new()
	right_page.name = "RightPage"
	right_page.position = Vector2(580, 85)
	right_page.size = Vector2(410, 520)
	book.add_child(right_page)

	var right_paper := TextureRect.new()
	right_paper.name = "RightPaper"
	right_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_page.add_child(right_paper)

	var right_text := TextEdit.new()
	right_text.name = "RightText"
	right_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right_text.add_theme_font_size_override("font_size", 22)
	right_page.add_child(right_text)

	var previous := Button.new()
	previous.name = "PreviousButton"
	previous.text = "<"
	previous.position = Vector2(60, 630)
	book.add_child(previous)

	var next := Button.new()
	next.name = "NextButton"
	next.text = ">"
	next.position = Vector2(1010, 630)
	book.add_child(next)

	var numbers := HBoxContainer.new()
	numbers.name = "PageNumbers"
	numbers.position = Vector2(430, 640)
	numbers.add_theme_constant_override("separation", 100)
	book.add_child(numbers)

	var left_number := Label.new()
	left_number.name = "LeftNumber"
	left_number.text = "1"
	numbers.add_child(left_number)

	var right_number := Label.new()
	right_number.name = "RightNumber"
	right_number.text = "2"
	numbers.add_child(right_number)

	var close := Button.new()
	close.name = "CloseButton"
	close.text = "X"
	close.position = Vector2(1040, 20)
	book.add_child(close)

	# Assign ownership so all nodes are saved.
	set_owners(root, root)

	var scene := PackedScene.new()
	var result := scene.pack(root)

	if result == OK:
		ResourceSaver.save(
			scene,
            "res://Journal.tscn"
		)
		print("Journal scene generated successfully!")

	root.free()


func set_owners(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		set_owners(child, scene_root)
