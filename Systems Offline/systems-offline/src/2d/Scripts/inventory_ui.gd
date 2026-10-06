class_name InventoryUI
extends Control

@onready var ui_manager: UI_Manager = get_parent()
@onready var item_inspector: ItemInspector = $"../ItemInspector"
@onready var item_grid: GridContainer = $Panel/MarginContainer/HBoxContainer/GridSection/ItemGrid

@export var slot_scene: PackedScene

func _ready() -> void:
	Inventory.inventory_update.connect(update_ui)
	update_ui()

func update_ui() -> void:
	for child in item_grid.get_children():
		child.queue_free()
		
	for item in Inventory.inventory:
		var slot: InventorySlot = slot_scene.instantiate()
		item_grid.add_child(slot)
		slot.set_item(item)
		slot.slot_clicked.connect(inspect_ui)

func inspect_ui(item: ItemData) -> void:
	if item and item.inspect_scene:
		item_inspector.setup_inspection(item)
		item_inspector.show()
		item_inspector.move_to_front()
		if Inventory.tutorial > 0:
			Notification.show_message("You can rotate by holding left mouse button and zoom with scroll wheel")
