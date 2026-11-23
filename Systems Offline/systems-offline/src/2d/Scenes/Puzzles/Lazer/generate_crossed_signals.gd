@tool
extends EditorScript
## One-time Godot 4.7 editor generator.
## Put this file beside crossed_signals_board.gd and crossed_signals_puzzle.gd,
## open it in the Script Editor, then choose File > Run (Ctrl+Shift+X).
## Creates CrossedSignals.tscn in the SAME folder as this script.


func _run() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	var destination: String = folder.path_join("CrossedSignals.tscn")

	if FileAccess.file_exists(destination):
		push_warning("CrossedSignals.tscn already exists. Move or rename it before rerunning the generator.")
		return

	var puzzle_script := load(folder.path_join("crossed_signals_puzzle.gd")) as Script
	var board_script := load(folder.path_join("crossed_signals_board.gd")) as Script
	if puzzle_script == null or board_script == null:
		push_error("Missing runtime scripts. Keep all three .gd files in the same folder.")
		return

	var root := Control.new()
	root.name = "CrossedSignals"
	root.set_script(puzzle_script)
	root.custom_minimum_size = Vector2(320, 250)
	root.size = Vector2(1050, 740)
	_full_rect(root)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("#071311")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, background, root)
	_full_rect(background)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_add(root, margin, root)
	_full_rect(margin)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 9)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add(margin, layout, root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 20)
	_add(layout, header, root)

	var title := _label("Title", "CROSSED SIGNALS  //  RELAY CALIBRATION", 22, "#8de8c3")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(header, title, root)

	var status := _label("Status", "0/2 receivers online  |  0/4 relays deployed", 13, "#b7d7d3")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(header, status, root)

	var instructions := _label(
		"Instructions",
		"Drag the four universal relays from their docks. Each red/blue channel needs TWO relays. Walls block beams. Both receivers must work at once.",
		13, "#9dc4b8"
	)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(layout, instructions, root)

	var frame := PanelContainer.new()
	frame.name = "BoardFrame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 180)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#101e24")
	frame_style.border_color = Color("#347f66")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", frame_style)
	_add(layout, frame, root)

	var board := Control.new()
	board.name = "Board"
	board.set_script(board_script)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.clip_contents = true
	_add(frame, board, root)

	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation", 10)
	_add(layout, controls, root)

	var reset := Button.new()
	reset.name = "ResetButton"
	reset.text = "RESET RELAYS"
	reset.custom_minimum_size = Vector2(135, 37)
	_style_button(reset, "#12372d", "#3ab68b")
	_add(controls, reset, root)

	var hint := Button.new()
	hint.name = "HintButton"
	hint.text = "SHOW HINT"
	hint.custom_minimum_size = Vector2(110, 37)
	_style_button(hint, "#12242a", "#456d6e")
	_add(controls, hint, root)

	var instruction_right := _label("ControlTip", "Drag: move relay  |  Return to its numbered dock: put away", 12, "#8aafa5")
	instruction_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	instruction_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_right.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(controls, instruction_right, root)

	var hint_label := _label(
		"HintLabel", "Drag R1–R4 freely. Every color needs exactly two relays; a relay cannot serve both colors.",
		13, "#b5cbbf"
	)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(layout, hint_label, root)

	var packed := PackedScene.new()
	var pack_result: Error = packed.pack(root)
	if pack_result != OK:
		push_error("Failed to pack CrossedSignals scene: %s" % error_string(pack_result))
		root.free()
		return

	var save_result: Error = ResourceSaver.save(packed, destination)
	if save_result != OK:
		push_error("Failed to save %s: %s" % [destination, error_string(save_result)])
	else:
		print("Crossed Signals generated: ", destination)
		print("Open CrossedSignals.tscn and press F6 to test it.")
	root.free()


func _add(parent: Node, child: Node, scene_root: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root


func _full_rect(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _label(node_name: String, content: String, font_size: int, tint: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(tint))
	return label


func _style_button(button: Button, background_hex: String, border_hex: String) -> void:
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("#d4ffe9"))
	for style_name in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(background_hex)
		box.border_color = Color(border_hex)
		box.set_border_width_all(2 if style_name != "normal" else 1)
		box.set_corner_radius_all(4)
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
		if style_name == "hover":
			box.bg_color = Color("#1e5541")
		elif style_name == "pressed":
			box.bg_color = Color("#317252")
		button.add_theme_stylebox_override(style_name, box)
