
extends Control

@onready var top_panel: PanelContainer = $TopNotification
@onready var top_type: Label = $TopNotification/VBoxContainer/NotificationType
@onready var top_label: Label = $TopNotification/VBoxContainer/MessageLabel

@onready var subtitle_panel: PanelContainer = $SubtitlePanel
@onready var speaker_label: Label = $SubtitlePanel/VBoxContainer/SpeakerLabel
@onready var subtitle_label: Label = $SubtitlePanel/VBoxContainer/SubtitleLabel

@onready var top_timer: Timer = $TopTimer
@onready var subtitle_timer: Timer = $SubtitleTimer

var top_tween: Tween
var subtitle_tween: Tween


func _ready() -> void:
	top_panel.hide()
	subtitle_panel.hide()

	top_timer.one_shot = true
	subtitle_timer.one_shot = true

	top_timer.timeout.connect(_hide_top)
	subtitle_timer.timeout.connect(_hide_subtitle)

	Notification.notification.connect(show_pickup_notification)
	Notification.locked.connect(locked_message)
	Notification.message.connect(show_message_top_center)
	Notification.hide.connect(hide_message)
	Notification.subtitle.connect(show_subtitle)


# -------------------------------
# TOP NOTIFICATIONS
# -------------------------------

func show_pickup_notification(item_data: Variant) -> void:
	var item_name: String

	if item_data is ItemData:
		item_name = item_data.item_name
	else:
		item_name = str(item_data)

	show_top("YOU HAVE PICKED UP: ", item_name, 2.5)


func show_top(
	category: String,
	message: String,
	duration: float = 2.5
) -> void:
	if top_tween and top_tween.is_running():
		top_tween.kill()

	top_timer.stop()

	top_type.text = category
	top_label.text = message

	top_panel.modulate.a = 0.0
	top_panel.show()

	top_tween = create_tween()
	top_tween.tween_property(
		top_panel, "modulate:a", 1.0, 0.2
	)

	top_timer.start(duration)


func _hide_top() -> void:
	if top_tween and top_tween.is_running():
		top_tween.kill()

	top_tween = create_tween()
	top_tween.tween_property(
		top_panel, "modulate:a", 0.0, 0.25
	)
	top_tween.tween_callback(top_panel.hide)


# -------------------------------
# CHARACTER SUBTITLES
# -------------------------------

func show_subtitle(
	message: String,
	speaker: String = "MC",
	duration: float = 3.5
) -> void:
	if subtitle_tween and subtitle_tween.is_running():
		subtitle_tween.kill()

	subtitle_timer.stop()

	speaker_label.text = speaker
	subtitle_label.text = message

	subtitle_panel.modulate.a = 0.0
	subtitle_panel.show()

	subtitle_tween = create_tween()
	subtitle_tween.tween_property(
		subtitle_panel, "modulate:a", 1.0, 0.2
	)

	subtitle_timer.start(duration)


func _hide_subtitle() -> void:
	if subtitle_tween and subtitle_tween.is_running():
		subtitle_tween.kill()

	subtitle_tween = create_tween()
	subtitle_tween.tween_property(
		subtitle_panel, "modulate:a", 0.0, 0.3
	)
	subtitle_tween.tween_callback(subtitle_panel.hide)


# -------------------------------
# EXISTING SIGNAL COMPATIBILITY
# -------------------------------

func show_message_top_center(
	message: String,
	top: bool
) -> void:
	if top:
		show_top("SYSTEM MESSAGE", message)
	else:
		show_subtitle(message)


func locked_message() -> void:
	show_subtitle(
		"It's locked. There must be another way in."
	)


func hide_message() -> void:
	top_timer.stop()
	subtitle_timer.stop()
	_hide_top()
	_hide_subtitle()
