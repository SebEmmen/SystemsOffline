extends Control

@onready var message_label: Label = $MarginContainer/Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Notification.notification.connect(show_message)

func show_message() -> void:
	message_label.text = "hello"
	print("Hello")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
