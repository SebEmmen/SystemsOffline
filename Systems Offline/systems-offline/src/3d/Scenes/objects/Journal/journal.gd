
extends CanvasLayer

const SAVE_PATH := "user://journal.json"
const TOTAL_PAGES := 20

# --------------------------------------------------
# QUEST SCENES
# --------------------------------------------------

const MAIN_QUEST = preload(
	"res://src/2d/Scenes/JournalPages/Quests/MainQuest.tscn"
)

const TUTORIAL_QUEST = preload(
	"res://src/2d/Scenes/JournalPages/Quests/TutorialQuest.tscn"
)

const ELEVATOR_QUEST = preload(
	"res://src/2d/Scenes/JournalPages/Quests/ElevatorQuest.tscn"
)

const COMMUNICATIONS_QUEST = preload(
	"res://src/2d/Scenes/JournalPages/Quests/CommunicationsQuest.tscn"
)

# Keep the original enum values for save compatibility.
enum JournalTab {
	BIRDS,
	DIARY,
	QUESTS,
	NOTES
}

# --------------------------------------------------
# NODE REFERENCES
# --------------------------------------------------

@onready var journal_ui: Control = $JournalUI

@onready var left_text: TextEdit = $JournalUI/CenterContainer/JournalBook/LeftPage/LeftText
@onready var right_text: TextEdit = $JournalUI/CenterContainer/JournalBook/RightPage/RightText

@onready var left_content: Control = $JournalUI/CenterContainer/JournalBook/LeftPage/LeftContent
@onready var right_content: Control = $JournalUI/CenterContainer/JournalBook/RightPage/RightContent

@onready var previous_button: Button = $JournalUI/CenterContainer/JournalBook/PreviousButton
@onready var next_button: Button = $JournalUI/CenterContainer/JournalBook/NextButton
@onready var close_button: Button = $JournalUI/CenterContainer/JournalBook/CloseButton

@onready var left_number: Label = $JournalUI/CenterContainer/JournalBook/LeftPage/LeftNumber
@onready var right_number: Label = $JournalUI/CenterContainer/JournalBook/RightPage/RightNumber

@onready var quests_tab: Button = $JournalUI/CenterContainer/JournalBook/TabBar/QuestsTab
@onready var diary_tab: Button = $JournalUI/CenterContainer/JournalBook/TabBar/DiaryTab
@onready var birds_tab: Button = $JournalUI/CenterContainer/JournalBook/TabBar/BirdsTab
@onready var notes_tab: Button = $JournalUI/CenterContainer/JournalBook/TabBar/NotesTab

# --------------------------------------------------
# DATA
# --------------------------------------------------

var pages: Array[String] = []

var quest_scene_lookup: Dictionary = {
	"main": MAIN_QUEST,
	"tutorial": TUTORIAL_QUEST,
	"elevator": ELEVATOR_QUEST,
	"communications": COMMUNICATIONS_QUEST
}

var bird_pages: Array[String] = []
var diary_pages: Array[String] = []

var current_tab: JournalTab = JournalTab.NOTES
var current_spread: int = 0

var tab_spreads := {
	JournalTab.BIRDS: 0,
	JournalTab.DIARY: 0,
	JournalTab.QUESTS: 0,
	JournalTab.NOTES: 0
}

var is_open: bool = false
var updating_pages: bool = false

var previous_mouse_mode: Input.MouseMode
var was_paused: bool = false


# --------------------------------------------------
# READY
# --------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	journal_ui.visible = false

	# Create the 20 editable notes pages.
	for i in range(TOTAL_PAGES):
		pages.append("")

	initialize_collections()
	load_journal()

	# Navigation buttons.
	previous_button.pressed.connect(previous_spread)
	next_button.pressed.connect(next_spread)
	close_button.pressed.connect(close_journal)

	# Bookmark buttons.
	quests_tab.pressed.connect(
		func(): switch_tab(JournalTab.QUESTS)
	)

	diary_tab.pressed.connect(
		func(): switch_tab(JournalTab.DIARY)
	)

	birds_tab.pressed.connect(
		func(): switch_tab(JournalTab.BIRDS)
	)

	notes_tab.pressed.connect(
		func(): switch_tab(JournalTab.NOTES)
	)
	
	QuestManager.progress_changed.connect(
		_on_quest_progress_changed
	)

	# Track changes to editable notes.
	left_text.text_changed.connect(save_current_pages)
	right_text.text_changed.connect(save_current_pages)

	style_handwriting(left_text)
	style_handwriting(right_text)

	update_tab_content()


# --------------------------------------------------
# INPUT
# --------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and not event.is_echo():
		if is_open:
			close_journal()
		else:
			open_journal()

		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel") and is_open:
		close_journal()
		get_viewport().set_input_as_handled()


# --------------------------------------------------
# OPEN / CLOSE
# --------------------------------------------------

func open_journal() -> void:
	if is_open:
		return

	is_open = true

	previous_mouse_mode = Input.mouse_mode
	was_paused = get_tree().paused

	journal_ui.visible = true

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	update_tab_content()

	left_text.release_focus()
	right_text.release_focus()


func close_journal() -> void:
	if not is_open:
		return

	if current_tab == JournalTab.NOTES:
		save_current_pages()

	tab_spreads[current_tab] = current_spread
	save_journal()

	left_text.release_focus()
	right_text.release_focus()

	is_open = false
	journal_ui.visible = false

	get_tree().paused = was_paused
	Input.mouse_mode = previous_mouse_mode


# --------------------------------------------------
# COLLECTION DATA
# --------------------------------------------------

func initialize_collections() -> void:
	bird_pages = [
		"Bird Encyclopedia\n\nDiscover birds to unlock information about them.",
		"No birds discovered yet.",
		"Forest Birds\n\nSpecies information will appear here.",
		"Observations\n\nHabitat, behavior, and calls."
	]

	diary_pages = [
		"Dialogue History\n\nPreviously heard conversations appear here.",
		"No dialogue recorded yet.",
		"Day 1\n\nShip systems are offline.",
		"Day 2\n\nCommunications remain unavailable."
	]


func get_active_pages() -> Array[String]:
	match current_tab:
		JournalTab.BIRDS:
			return bird_pages

		JournalTab.DIARY:
			return diary_pages

		JournalTab.NOTES:
			return pages

	return []


func get_max_spread() -> int:
	if current_tab == JournalTab.QUESTS:
		return maxi(
			0,
			QuestManager.get_visible_quests().size() - 1
		)

	return maxi(
		0,
		(get_active_pages().size() - 1) / 2
	)

# --------------------------------------------------
# TAB SWITCHING
# --------------------------------------------------

func switch_tab(new_tab: JournalTab) -> void:
	if current_tab == new_tab:
		return

	# Save notes before leaving the Notes tab.
	if current_tab == JournalTab.NOTES:
		save_current_pages()

	# Remember the previous tab's spread.
	tab_spreads[current_tab] = current_spread

	current_tab = new_tab

	if current_tab == JournalTab.QUESTS:
		current_spread = 0
	else:
		current_spread = tab_spreads[current_tab]

	current_spread = clampi(
		current_spread,
		0,
		get_max_spread()
	)

	update_tab_content()
	save_journal()


func update_tab_content() -> void:
	var editable := current_tab == JournalTab.NOTES

	left_text.editable = editable
	right_text.editable = editable

	update_pages()
	update_tab_buttons()


func update_tab_buttons() -> void:
	quests_tab.button_pressed = current_tab == JournalTab.QUESTS
	diary_tab.button_pressed = current_tab == JournalTab.DIARY
	birds_tab.button_pressed = current_tab == JournalTab.BIRDS
	notes_tab.button_pressed = current_tab == JournalTab.NOTES


# --------------------------------------------------
# PAGE CONTENT
# --------------------------------------------------

func clear_content(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()



func show_quest_page() -> void:
	var visible_quests := QuestManager.get_visible_quests()

	if current_spread >= visible_quests.size():
		return

	var quest_id: String = visible_quests[current_spread]

	if not quest_scene_lookup.has(quest_id):
		push_warning("Missing quest scene: " + quest_id)
		return

	var scene: PackedScene = quest_scene_lookup[quest_id]
	var quest_page := scene.instantiate() as Control

	if quest_page == null:
		push_error("Quest scene root must be a Control.")
		return

	left_content.add_child(quest_page)

	quest_page.custom_minimum_size = Vector2.ZERO
	quest_page.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	update_quest_checkboxes(quest_page, quest_id)

func update_quest_checkboxes(
	quest_page: Control,
	quest_id: String
) -> void:
	var objectives_node := quest_page.get_node_or_null(
		"MarginContainer/VBoxContainer/Objectives"
	)

	if objectives_node == null:
		push_warning("Quest objectives container missing: " + quest_id)
		return

	var objective_ids := QuestManager.get_objective_ids(quest_id)

	for i in range(objective_ids.size()):
		var checkbox := objectives_node.get_node_or_null(
			"Objective" + str(i + 1)
		) as CheckBox

		if checkbox == null:
			continue

		var objective_id := objective_ids[i]

		# Decide whether the player can see this objective.
		checkbox.visible = QuestManager.is_objective_visible(
			quest_id,
			objective_id
		)

		# Display progress without allowing manual completion.
		checkbox.button_pressed = QuestManager.is_objective_completed(
			quest_id,
			objective_id
		)

		checkbox.disabled = true

func update_pages() -> void:
	updating_pages = true

	# Remove content from the previous spread.
	clear_content(left_content)
	clear_content(right_content)

	# ----------------------------------------------
	# QUESTS: Scene-based pages
	# ----------------------------------------------

	if current_tab == JournalTab.QUESTS:
		left_text.visible = false
		right_text.visible = false

		left_content.visible = true
		right_content.visible = true

		show_quest_page()

		left_number.text = str(current_spread * 2 + 1)
		right_number.text = str(current_spread * 2 + 2)

		update_navigation_buttons()

		updating_pages = false
		return

	# ----------------------------------------------
	# BIRDS / DIARY / NOTES: Text-based pages
	# ----------------------------------------------

	left_content.visible = false
	right_content.visible = false

	left_text.visible = true
	right_text.visible = true

	var collection := get_active_pages()

	var left_index := current_spread * 2
	var right_index := left_index + 1

	left_text.text = ""
	right_text.text = ""

	if left_index < collection.size():
		left_text.text = collection[left_index]

	if right_index < collection.size():
		right_text.text = collection[right_index]

	left_number.text = str(left_index + 1)
	right_number.text = str(right_index + 1)

	update_navigation_buttons()

	left_text.scroll_vertical = 0
	right_text.scroll_vertical = 0

	updating_pages = false


# --------------------------------------------------
# NOTES SAVING
# --------------------------------------------------

func save_current_pages() -> void:
	# Only the Notes tab may modify saved pages.
	if current_tab != JournalTab.NOTES:
		return

	if updating_pages:
		return

	var left_index := current_spread * 2
	var right_index := left_index + 1

	if left_index < pages.size():
		pages[left_index] = left_text.text

	if right_index < pages.size():
		pages[right_index] = right_text.text


# --------------------------------------------------
# PAGE NAVIGATION
# --------------------------------------------------

func next_spread() -> void:
	if current_spread >= get_max_spread():
		return

	if current_tab == JournalTab.NOTES:
		save_current_pages()

	current_spread += 1
	tab_spreads[current_tab] = current_spread

	update_pages()


func previous_spread() -> void:
	if current_spread <= 0:
		return

	if current_tab == JournalTab.NOTES:
		save_current_pages()

	current_spread -= 1
	tab_spreads[current_tab] = current_spread

	update_pages()


# --------------------------------------------------
# SAVE
# --------------------------------------------------

func save_journal() -> void:
	var data := {
		"pages": pages,
		"current_spread": tab_spreads[JournalTab.NOTES],
		"current_tab": current_tab,
		"tab_spreads": {
			"birds": tab_spreads[JournalTab.BIRDS],
			"diary": tab_spreads[JournalTab.DIARY],
			"quests": tab_spreads[JournalTab.QUESTS],
			"notes": tab_spreads[JournalTab.NOTES]
		}
	}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error("Journal: Failed to save journal.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Journal saved!")


# --------------------------------------------------
# LOAD
# --------------------------------------------------

func load_journal() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error("Journal: Failed to load journal.")
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if not data is Dictionary:
		push_warning("Journal: Invalid save data.")
		return

	# Restore existing notes.
	var saved_pages = data.get("pages", [])

	if saved_pages is Array:
		for i in range(mini(saved_pages.size(), TOTAL_PAGES)):
			pages[i] = str(saved_pages[i])

	# Support older journal saves.
	var old_spread := int(
		data.get("current_spread", 0)
	)

	var saved_spreads = data.get("tab_spreads", {})

	if saved_spreads is Dictionary:
		tab_spreads[JournalTab.BIRDS] = int(
			saved_spreads.get("birds", 0)
		)

		tab_spreads[JournalTab.DIARY] = int(
			saved_spreads.get("diary", 0)
		)

		tab_spreads[JournalTab.QUESTS] = int(
			saved_spreads.get("quests", 0)
		)

		tab_spreads[JournalTab.NOTES] = int(
			saved_spreads.get("notes", old_spread)
		)

	current_tab = JournalTab.NOTES

	var saved_tab := int(
		data.get("current_tab", JournalTab.NOTES)
	)

	if saved_tab >= JournalTab.BIRDS and saved_tab <= JournalTab.NOTES:
		current_tab = saved_tab

	current_spread = tab_spreads[current_tab]

	current_spread = clampi(
		current_spread,
		0,
		get_max_spread()
	)

	tab_spreads[current_tab] = current_spread

	print("Journal loaded!")


# --------------------------------------------------
# HANDWRITING STYLE
# --------------------------------------------------

func style_handwriting(text_edit: TextEdit) -> void:
	var font := load(
		"res://src/2d/Assets/Journal/Font/Caveat-Regular.ttf"
	) as Font

	if font:
		text_edit.add_theme_font_override("font", font)

	text_edit.add_theme_font_size_override(
		"font_size",
		26
	)

	text_edit.add_theme_color_override(
		"font_color",
		Color("#493526")
	)

	text_edit.add_theme_color_override(
		"caret_color",
		Color("#493526")
	)

	text_edit.add_theme_constant_override(
		"line_spacing",
		6
	)

	var empty := StyleBoxEmpty.new()

	text_edit.add_theme_stylebox_override(
		"normal",
		empty
	)

	text_edit.add_theme_stylebox_override(
		"focus",
		empty
	)

	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.scroll_smooth = true
	text_edit.minimap_draw = false

func update_navigation_buttons() -> void:
	var has_previous := current_spread > 0
	var has_next := current_spread < get_max_spread()

	previous_button.visible = has_previous
	previous_button.disabled = not has_previous

	next_button.visible = has_next
	next_button.disabled = not has_next
	
func _on_quest_progress_changed() -> void:
	if current_tab != JournalTab.QUESTS:
		return

	current_spread = clampi(
		current_spread,
		0,
		get_max_spread()
	)

	tab_spreads[current_tab] = current_spread
	update_pages()
# --------------------------------------------------
# CLEANUP
# --------------------------------------------------

func _exit_tree() -> void:
	if is_open and current_tab == JournalTab.NOTES:
		save_current_pages()

	tab_spreads[current_tab] = current_spread
	save_journal()
