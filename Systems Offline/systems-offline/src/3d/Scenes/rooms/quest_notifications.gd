
extends Node

@export var notification_ui: Node

const OBJECTIVE_NAMES := {
	
	"main": {
		"escape_spaceship": "Find a way to escape the spaceship"
	},

	"tutorial": {
		"find_key": "Find the key",
		"unlock_cover": "Unlock the keypad cover",
		"discover_code": "Discover the access code",
		"escape": "Escape the tutorial room"
	},
	"elevator": {
		"power": "Turn on elevator power",
		"multitool": "Grab the multitool",
		"rewire": "Rewire the elevator"
	},
	"communications": {
		"power": "Turn on communications power",
		"puzzle": "Finish the communications puzzle",
		"key": "Find the multitool key",
		"multitool": "Acquire the multitool"
	}
}


func _ready() -> void:
	QuestManager.objective_completed.connect(
		_on_objective_completed
	)

	QuestManager.quest_completed.connect(
		_on_quest_completed
	)

	QuestManager.quest_unlocked.connect(
		_on_quest_unlocked
	)


func show_quest_notification(message: String) -> void:
	if notification_ui == null:
		push_warning("QuestNotifications: NotificationUI not assigned.")
		return

	if not notification_ui.has_method("show_message_top_center"):
		push_warning("QuestNotifications: NotificationUI method missing.")
		return

	notification_ui.show_message_top_center(message, true)


func _on_objective_completed(
	quest_id: String,
	objective_id: String
) -> void:
	var objective_name := objective_id.replace("_", " ").capitalize()

	if OBJECTIVE_NAMES.has(quest_id):
		var names: Dictionary = OBJECTIVE_NAMES[quest_id]
		objective_name = str(names.get(objective_id, objective_name))

	show_quest_notification(
		"Objective completed: " + objective_name
	)


func _on_quest_completed(quest_id: String) -> void:
	show_quest_notification(
		"Quest completed: " +
		QuestManager.get_quest_title(quest_id)
	)


func _on_quest_unlocked(quest_id: String) -> void:
	show_quest_notification(
		"New quest: " +
		QuestManager.get_quest_title(quest_id)
	)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F5:
				QuestManager.record_event("tutorial_key_found")
