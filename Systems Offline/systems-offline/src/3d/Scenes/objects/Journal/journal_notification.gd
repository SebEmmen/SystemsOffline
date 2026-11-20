
extends Control

@onready var journal_icon: TextureRect = $JournalIcon
@onready var notification_dot: Panel = $JournalIcon/NotificationDot
@onready var pencil_sound: AudioStreamPlayer = $PencilSound


func _ready() -> void:
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	journal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Respond when unread quest status changes.
	QuestManager.unread_changed.connect(
		_on_unread_changed
	)

	# Respond when a new quest update occurs.
	QuestManager.journal_update.connect(
		_on_journal_update
	)

	# Initialize visibility from existing progress.
	_update_visibility()


func _on_unread_changed() -> void:
	_update_visibility()


func _update_visibility() -> void:
	var has_unread: bool = QuestManager.has_unread_quests()

	print("[JOURNAL] Unread quests: ", QuestManager.get_unread_quests())

	visible = has_unread
	notification_dot.visible = has_unread



func _on_journal_update(quest_id: String) -> void:
	print("[SOUND] Journal update: ", quest_id)

	if pencil_sound.stream == null:
		print("[SOUND] No audio stream assigned!")
		return

	print("[SOUND] Stream: ", pencil_sound.stream.resource_path)
	print("[SOUND] Length: ", pencil_sound.stream.get_length())
	print("[SOUND] Volume: ", pencil_sound.volume_db)
	print("[SOUND] Bus: ", pencil_sound.bus)

	pencil_sound.stop()
	pencil_sound.play()

	print("[SOUND] Is playing: ", pencil_sound.playing)
