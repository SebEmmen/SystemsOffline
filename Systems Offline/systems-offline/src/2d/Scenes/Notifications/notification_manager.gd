extends Node

signal notification
signal locked
signal message
signal hide

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func locked_notification() -> void:
	locked.emit()

func show_pickup_notification(item_data: ItemData) -> void:
	notification.emit(item_data)

func show_message(text: String, top: bool) -> void:
	message.emit(text, top)

func hide_message() -> void:
	hide.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
