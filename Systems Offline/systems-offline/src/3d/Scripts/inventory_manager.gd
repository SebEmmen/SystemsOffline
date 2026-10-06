extends Node

@export var inventory: Array[ItemData]
@onready var tutorial: bool

signal inventory_update 

var binoculars: ItemData = preload("res://src/3d/Resources/Binoculars.tres")

func _ready() -> void:
	add_item(binoculars)
	tutorial = true

func add_item(item_data: ItemData) -> void:
	if item_data:
		inventory.append(item_data)
		inventory_update.emit()
	for item in inventory:
		print(item.item_name, " ", item.item_id)

func has_item(item_id: String) -> bool:
	for item in inventory:
		if item.item_id == item_id:
			return true
	return false

func remove_item_by_id(item_id: String) -> void:
	for item in inventory:
		if item.item_id == item_id:
			inventory.erase(item)
			inventory_update.emit()
			break
