
@tool
extends EditorScript

const QUEST_FOLDER := "res://src/2d/Scenes/JournalPages/Quests/"

const QUESTS := [
	{
		"filename": "TutorialQuest.tscn",
		"title": "Complete Tutorial Room",
		"description": "Find a way to escape the tutorial room.",
		"objectives": [
			"Find the key",
			"Unlock the keypad",
			"Figure out the combination"
		]
	},
	{
		"filename": "ElevatorQuest.tscn",
		"title": "Complete the Elevator Puzzle",
		"description": "Solve the elevator puzzle and continue through the ship.",
		"objectives": [
			"Finish the communications puzzle",
			"Grab the multitool"
		]
	},
	{
		"filename": "CommunicationsQuest.tscn",
		"title": "Finish the Communications Room",
		"description": "Restore the communications room and obtain the multitool.",
		"objectives": [
			"Turn on the power",
			"Finish the communications puzzle",
			"Find the key for the multitool",
			"Acquire the multitool"
		]
	}
]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(QUEST_FOLDER)
	)

	for quest_data in QUESTS:
		create_quest_scene(quest_data)

	print("All quest scenes generated!")


func create_quest_scene(data: Dictionary) -> void:
	var root := Control.new()
	root.name = "QuestPage"
	root.custom_minimum_size = Vector2(360, 460)
	root.size = Vector2(360, 460)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Page margins.
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	root.add_child(margin)
	margin.owner = root
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)

	# Vertical layout.
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	margin.add_child(vbox)
	vbox.owner = root
	vbox.add_theme_constant_override("separation", 15)

	# Quest title.
	var title := Label.new()
	title.name = "QuestTitle"
	title.text = data["title"]
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#493526"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	title.owner = root

	# Separator.
	var separator := HSeparator.new()
	separator.name = "HSeparator"
	vbox.add_child(separator)
	separator.owner = root

	# Description.
	var description := Label.new()
	description.name = "QuestDescription"
	description.text = data["description"]
	description.add_theme_font_size_override("font_size", 22)
	description.add_theme_color_override("font_color", Color("#493526"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(description)
	description.owner = root

	# Objectives container.
	var objectives := VBoxContainer.new()
	objectives.name = "Objectives"
	objectives.add_theme_constant_override("separation", 12)
	vbox.add_child(objectives)
	objectives.owner = root

	var objective_list: Array = data["objectives"]

	for i in range(objective_list.size()):
		var checkbox := CheckBox.new()
		checkbox.name = "Objective" + str(i + 1)
		checkbox.text = objective_list[i]
		checkbox.disabled = true
		checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		checkbox.add_theme_font_size_override("font_size", 21)
		checkbox.add_theme_color_override(
			"font_color",
			Color("#493526")
		)
		checkbox.add_theme_color_override(
			"font_disabled_color",
			Color("#493526")
		)

		objectives.add_child(checkbox)
		checkbox.owner = root

	# Pack and save.
	var packed := PackedScene.new()
	var result := packed.pack(root)

	if result != OK:
		push_error("Failed to pack: " + data["filename"])
		root.free()
		return

	var save_path: String = QUEST_FOLDER + data["filename"]
	var save_result := ResourceSaver.save(packed, save_path)

	if save_result != OK:
		push_error("Failed to save: " + save_path)
	else:
		print("Created: ", save_path)

	root.free()
