extends Control

@onready var top_center_message_label: Label = $"Top Center label"
@onready var bot_center_message_label: Label = $"Bottom Center label"
@onready var message_timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	top_center_message_label.visible = false
	Notification.notification.connect(show_pickup_notification)
	Notification.locked.connect(locked_message)
	Notification.message.connect(show_message_top_center)
	Notification.hide.connect(hide_message)

func show_pickup_notification(item_data: ItemData) -> void:
	top_center_message_label.text = "You have picked up: " + item_data.item_name
	top_center_message_label.visible = true
	message_timer.start()

func show_message_top_center(text: String, top: bool) -> void:
	if top:
		top_center_message_label.text = text
		top_center_message_label.visible = true
	else:
		bot_center_message_label.text = text
		bot_center_message_label.visible = true
	

func locked_message() -> void:
	top_center_message_label.text = "Its locked!"
	top_center_message_label.visible = true
	message_timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func hide_message() -> void:
	top_center_message_label.visible = false
	bot_center_message_label.visible = false

func _on_timer_timeout() -> void:
	top_center_message_label.visible = false # Replace with function body.
	bot_center_message_label.visible = false
