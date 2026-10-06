extends Control

@onready var message_label: Label = $MarginContainer/Label
@onready var message_timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	message_label.visible = false
	Notification.notification.connect(show_message)
	Notification.locked.connect(locked_message)

func show_message(item_data: ItemData) -> void:
	message_label.text = "You have picked up: " + item_data.item_name
	message_label.visible = true
	message_timer.start()
	
func locked_message() -> void:
	message_label.text = "Its locked!"
	message_label.visible = true
	message_timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	message_label.visible = false # Replace with function body.
