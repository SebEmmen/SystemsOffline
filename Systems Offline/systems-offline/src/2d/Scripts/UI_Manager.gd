class_name UI_Manager
extends CanvasLayer

enum Menu {
	NONE,
	PAUSE,
	INVENTORY,
	BOOK
}

@onready var pause_menu: Control = $PauseMenu
@onready var inventory_ui: Control = get_node_or_null("InventoryUI")
@export var book_menu: Control
@export var book_anchor: Node3D

@export var player: CharacterBody3D

var current_menu: Menu = Menu.NONE
	

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.visible = false
	if inventory_ui:
		inventory_ui.visible = false

	if book_menu == null:
		book_menu = get_node_or_null("BookMenu")
		if book_menu == null:
			var book_scene = load("res://src/2d/Scenes/BookMenu/BookMenu.tscn")
			if book_scene:
				book_menu = book_scene.instantiate()
				add_child(book_menu)

	if book_menu:
		book_menu.visible = false
		if book_menu.has_signal("close_requested"):
			book_menu.close_requested.connect(close_menu)
			
	if book_anchor:
		book_anchor.hide()


func _get_player() -> CharacterBody3D:
	if player:
		return player
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _unhandled_input(event: InputEvent) -> void:
	# ESCAPE
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match current_menu:
			Menu.NONE:
				open_menu(Menu.PAUSE)

			Menu.PAUSE:
				if pause_menu and pause_menu.has_method("handle_cancel") and pause_menu.handle_cancel():
					return
				close_menu()

			Menu.INVENTORY:
				close_menu()

			Menu.BOOK:
				close_menu()

	# TAB
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		match current_menu:
			Menu.NONE:
				open_menu(Menu.BOOK)

			Menu.BOOK:
				close_menu()

			Menu.INVENTORY:
				close_menu()

			Menu.PAUSE:
				# Do nothing while paused
				pass


func open_menu(menu: Menu) -> void:
	current_menu = menu

	if pause_menu:
		pause_menu.visible = (menu == Menu.PAUSE)
	if inventory_ui:
		inventory_ui.visible = (menu == Menu.INVENTORY)
	if book_menu:
		book_menu.visible = (menu == Menu.BOOK)
	if book_anchor:
		book_anchor.visible = (menu == Menu.BOOK)

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var p = _get_player()
	if p:
		if p.has_method("release_mouse"):
			p.release_mouse()
		if p.has_method("disable_controls"):
			p.disable_controls()


func close_menu() -> void:
	if Inventory.tutorial > 1 and current_menu == Menu.INVENTORY:
		Notification.hide_message()
		Inventory.tutorial = 1
	current_menu = Menu.NONE

	if pause_menu:
		pause_menu.visible = false
	if inventory_ui:
		inventory_ui.visible = false
	if book_menu:
		book_menu.visible = false
	if book_anchor:
		book_anchor.visible = false

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Callable(Input, "set_mouse_mode").call_deferred(Input.MOUSE_MODE_CAPTURED)
	var p = _get_player()
	if p:
		if p.has_method("enable_controls"):
			p.enable_controls()
		elif p.has_method("capture_mouse"):
			p.capture_mouse()
			p.call_deferred("capture_mouse")


func _on_resume_button_pressed() -> void:
	close_menu()


func _on_quit_button_pressed() -> void:
	SaveManager.save_game()
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/2d/Scenes/MainMenu.tscn")
