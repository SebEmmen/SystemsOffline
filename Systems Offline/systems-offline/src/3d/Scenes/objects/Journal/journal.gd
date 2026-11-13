
extends CanvasLayer

const SAVE_PATH := "user://journal.json"
const TOTAL_PAGES := 20

@onready var journal_ui: Control = $JournalUI

@onready var left_text: TextEdit = $JournalUI/CenterContainer/JournalBook/LeftPage/LeftText
@onready var right_text: TextEdit = $JournalUI/CenterContainer/JournalBook/RightPage/RightText

@onready var previous_button: Button = $JournalUI/CenterContainer/JournalBook/PreviousButton
@onready var next_button: Button = $JournalUI/CenterContainer/JournalBook/NextButton
@onready var close_button: Button = $JournalUI/CenterContainer/JournalBook/CloseButton

@onready var left_number: Label = $JournalUI/CenterContainer/JournalBook/LeftPage/LeftNumber
@onready var right_number: Label = $JournalUI/CenterContainer/JournalBook/RightPage/RightNumber

var pages: Array[String] = []
var current_spread: int = 0
var is_open: bool = false

var previous_mouse_mode: Input.MouseMode
var was_paused: bool = false


func _ready() -> void:
	# Continue processing while gameplay is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	journal_ui.visible = false

	# Create empty pages.
	for i in range(TOTAL_PAGES):
		pages.append("")

	load_journal()

	# Connect buttons.
	previous_button.pressed.connect(previous_spread)
	next_button.pressed.connect(next_spread)
	close_button.pressed.connect(close_journal)

	# Track changes to both pages.
	left_text.text_changed.connect(save_current_pages)
	right_text.text_changed.connect(save_current_pages)

	update_pages()
	style_handwriting(left_text)
	style_handwriting(right_text)


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


func open_journal() -> void:
	if is_open:
		return

	is_open = true

	previous_mouse_mode = Input.mouse_mode
	was_paused = get_tree().paused

	journal_ui.visible = true

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	update_pages()

	# Prevent TextEdit from automatically capturing keyboard input.
	left_text.release_focus()
	right_text.release_focus()


func close_journal() -> void:
	if not is_open:
		return

	save_current_pages()
	save_journal()

	left_text.release_focus()
	right_text.release_focus()

	is_open = false
	journal_ui.visible = false

	get_tree().paused = was_paused
	Input.mouse_mode = previous_mouse_mode


func update_pages() -> void:
	var left_index := current_spread * 2
	var right_index := left_index + 1

	left_text.text = pages[left_index]
	right_text.text = pages[right_index]

	left_number.text = str(left_index + 1)
	right_number.text = str(right_index + 1)

	previous_button.disabled = current_spread == 0
	next_button.disabled = right_index >= TOTAL_PAGES - 1


func save_current_pages() -> void:
	var left_index := current_spread * 2
	var right_index := left_index + 1

	pages[left_index] = left_text.text
	pages[right_index] = right_text.text


func next_spread() -> void:
	if current_spread >= TOTAL_PAGES / 2 - 1:
		return

	save_current_pages()
	current_spread += 1
	update_pages()


func previous_spread() -> void:
	if current_spread <= 0:
		return

	save_current_pages()
	current_spread -= 1
	update_pages()


func save_journal() -> void:
	var data := {
		"pages": pages,
		"current_spread": current_spread
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Journal: Failed to save journal.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Journal saved!")


func load_journal() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_error("Journal: Failed to load journal.")
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if not data is Dictionary:
		push_warning("Journal: Invalid save data.")
		return

	var saved_pages = data.get("pages", [])

	if saved_pages is Array:
		for i in range(min(saved_pages.size(), TOTAL_PAGES)):
			pages[i] = str(saved_pages[i])

	current_spread = clampi(
		int(data.get("current_spread", 0)),
		0,
		TOTAL_PAGES / 2 - 1
	)

	print("Journal loaded!")
	
	
	

func style_handwriting(text_edit: TextEdit) -> void:
	var font := load(
        "res://src/2d/Assets/Journal/Font/Caveat-Regular.ttf"
	) as Font

	if font:
		text_edit.add_theme_font_override("font", font)

	text_edit.add_theme_font_size_override("font_size", 26)

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
	text_edit.add_theme_stylebox_override("normal", empty)
	text_edit.add_theme_stylebox_override("focus", empty)

	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.scroll_smooth = true
	text_edit.minimap_draw = false



func _exit_tree() -> void:
	if is_open:
		save_current_pages()

	save_journal()
