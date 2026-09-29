class_name InventoryUI
extends Control

@onready var ui_manager: UI_Manager = get_parent()
@export var slot_scene: PackedScene
@onready var item_grid: GridContainer = $Panel/MarginContainer/HBoxContainer/GridSection/ItemGrid

func _ready():
	Inventory.inventory_update.connect(update_ui)
	update_ui()

func update_ui() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	for item in Inventory.inventory:
		var slot = slot_scene.instantiate()
		item_grid.add_child(slot)
		slot.set_item(item)
