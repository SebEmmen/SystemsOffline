class_name InventorySlot
extends Control

@onready var texture_rect: TextureRect = $PanelContainer/MarginContainer/TextureRect
@onready var name_label: Label = $PanelContainer/VBoxContainer/MarginContainer/Label

var item_data: ItemData

signal slot_clicked(item: ItemData)

func set_item(data: ItemData) -> void:
	item_data = data
	if is_node_ready():
		_update_slot_visuals()

func _ready() -> void:
	_update_slot_visuals()

func _update_slot_visuals() -> void:
	if item_data:
		texture_rect.texture = item_data.inventory_icon
		name_label.text = item_data.item_name
	else:
		texture_rect.texture = null
		name_label.text = ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if item_data:
				print("Inspecting time!")
				slot_clicked.emit(item_data)
