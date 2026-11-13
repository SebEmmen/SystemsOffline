extends Node

# Existing signals
signal notification(item_data: Variant)
signal locked
signal message(text: String, top: bool)
signal hide_requested  # Renamed from 'hide' to avoid engine conflict

# New subtitle signal
signal subtitle(text: String, speaker: String, duration: float)


# -------------------------------
# EXISTING NOTIFICATIONS
# -------------------------------

func locked_notification() -> void:
	locked.emit()


func show_pickup_notification(item_data: Variant) -> void:
	notification.emit(item_data)


func show_message(text: String, top: bool) -> void:
	message.emit(text, top)


func show_message_after_delay(
	text: String,
	top: bool,
	delay: float
) -> void:
	await get_tree().create_timer(delay).timeout
	show_message(text, top)


func hide_message() -> void:
	hide_requested.emit()  # Updated to emit the new signal name


# -------------------------------
# CHARACTER SUBTITLES
# -------------------------------

func say(
	text: String,
	speaker: String = "PLAYER // COMMS",
	duration: float = 3.5
) -> void:
	subtitle.emit(text, speaker, duration)


func say_after_delay(
	text: String,
	delay: float,
	speaker: String = "PLAYER // COMMS",
	duration: float = 3.5
) -> void:
	await get_tree().create_timer(delay).timeout
	say(text, speaker, duration)
