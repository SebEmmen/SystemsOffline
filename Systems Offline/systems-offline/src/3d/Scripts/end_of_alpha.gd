extends Control
## Screen shown when the player finishes the alpha.
## Show it with: get_tree().change_scene_to_file("res://alpha_end_screen.tscn")

@export var title_text: String = "Thanks for playing the Alpha!"
@export_multiline var message_text: String = "You've reached the end of the current build.\nYour feedback will help shape the game, and we can't wait to show you what's next."
@export_file("*.tscn") var main_menu_scene: String = "res://main_menu.tscn"
## Leave empty to hide the feedback button.
@export var feedback_url: String = ""
@export var fade_in_time: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()

	# Fade in
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_in_time)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var message := Label.new()
	message.text = message_text
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 20)
	message.modulate = Color(1, 1, 1, 0.8)
	box.add_child(message)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	var menu_button := _make_button("Back to Main Menu", _on_menu_pressed)
	box.add_child(menu_button)

	if feedback_url != "":
		box.add_child(_make_button("Give Feedback", _on_feedback_pressed))

	box.add_child(_make_button("Quit Game", _on_quit_pressed))

	menu_button.grab_focus() # keyboard/controller support


func _make_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	return button


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene)


func _on_feedback_pressed() -> void:
	OS.shell_open(feedback_url)


func _on_quit_pressed() -> void:
	get_tree().quit()
