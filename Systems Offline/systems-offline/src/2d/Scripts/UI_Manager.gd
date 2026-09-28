class_name UI_Manager
extends CanvasLayer

enum Menu {
	NONE,
	PAUSE,
	INVENTORY
}

@onready var pause_menu: Control = $PauseMenu
@onready var inventory_ui: Control = $InventoryUI

var current_menu: Menu = Menu.NONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	pause_menu.visible = false
	inventory_ui.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# ESCAPE
	if event.is_action_pressed("ui_cancel"):
		match current_menu:
			Menu.NONE:
				open_menu(Menu.PAUSE)

			Menu.PAUSE:
				close_menu()

			Menu.INVENTORY:
				close_menu()

	# TAB
	elif event.is_action_pressed("inventory"):
		match current_menu:
			Menu.NONE:
				open_menu(Menu.INVENTORY)

			Menu.INVENTORY:
				close_menu()

			Menu.PAUSE:
				# Do nothing
				pass


func open_menu(menu: Menu) -> void:
	current_menu = menu

	match menu:
		Menu.PAUSE:
			pause_menu.visible = true
			inventory_ui.visible = false

		Menu.INVENTORY:
			inventory_ui.visible = true
			pause_menu.visible = false

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_menu() -> void:
	current_menu = Menu.NONE

	pause_menu.visible = false
	inventory_ui.visible = false

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_resume_button_pressed() -> void:
	close_menu()


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/2d/Scenes/MainMenu.tscn")
