extends Node

var inventory: Array[ItemData]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func add_item(item_data: Resource) -> void:
	inventory.append(item_data)
	print("Added ", item_data.item_name, " to your inventory")
	if inventory.is_empty():
		print("Inventory is empty")
	else:
		print("The following Items are in your inventory:")
	for n in inventory:
		print(n.item_name, ", ", n.item_id)

func has_item(item_id: String) -> bool:
	if inventory.is_empty():
		return false
	for item in inventory:
		if item.item_id == item_id:
			return true
	return false

func remove_item_by_id(item_id: String) -> void:
	if inventory.is_empty() or !has_item(item_id):
		return
	for item in inventory:
		if item.item_id == item_id:
			inventory.erase(item)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
