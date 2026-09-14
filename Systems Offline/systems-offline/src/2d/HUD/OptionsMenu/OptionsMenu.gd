extends CanvasLayer

@onready var options_menu: Control = $Control
@onready var pause_menu = $"../Control"


func _ready() -> void:
	options_menu.visible = true


func _on_sound_pressed() -> void:
	print("boop!")
	
func _on_back_pressed() -> void:
	options_menu.visible = false
	pause_menu.visible = true
	#print("Back!")
