extends Node

var inventory: Array[ItemData]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func add_item(item_data: Resource) -> void:
	inventory.append(item_data)
	print("Added ", item_data.item_name, " to your inventory")
	for n in inventory:
		print(n)

func has_item(item_id: String) -> bool:
	if inventory.is_empty():
		return false
	for item in inventory:
		if item.item_id == item_id:
			return true
	return false

func remove_item(item_data: Resource) -> void:
	inventory.erase(item_data)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
