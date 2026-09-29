class_name InventorySlot
extends Control

@onready var texture_rect: TextureRect = $PanelContainer/MarginContainer/TextureRect
@onready var name_label: Label = $PanelContainer/VBoxContainer/MarginContainer/Label
var item_data: ItemData

func set_item(data: ItemData) -> void:
	item_data = data
	# If the node is already in the tree, update visuals immediately
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
