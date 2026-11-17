
extends Node

signal objective_completed(quest_id: String, objective_id: String)
signal quest_unlocked(quest_id: String)
signal quest_completed(quest_id: String)
signal progress_changed

const QUEST_ORDER: Array[String] = [
	"tutorial",
	"communications",
	"elevator",
	"main",
]

const QUESTS := {
	"main": {
		"title": "Escape the Spaceship",
		"objectives": {
			"escape_spaceship": "spaceship_escaped"
		}
	},
	"tutorial": {
		"title": "Escape the Tutorial Room",
		"objectives": {
			"find_key": "tutorial_key_found",
			"discover_code": "tutorial_code_discovered",
			"escape": "tutorial_room_escaped"
		}
	},
	"elevator": {
		"title": "Fix the Elevator",
		"objectives": {
			"power": "elevator_power_on",
			"multitool": "multitool_acquired",
			"rewire": "elevator_rewired"
		}
	},
	"communications": {
		"title": "Finish the Communications Room",
		"objectives": {
			"power": "comms_power_on",
			"puzzle": "comms_puzzle_completed",
			"key": "multitool_key_found",
			"multitool": "multitool_acquired"
		}
	}
}

# Explicit objective order, independent of Dictionary order.
const OBJECTIVE_ORDER := {
	"main": [
		"escape_spaceship"
	],
	"tutorial": [
		"find_key",
		"discover_code",
		"escape"
	],
	"elevator": [
		"power",
		"multitool",
		"rewire"
	],
	"communications": [
		"power",
		"puzzle",
		"key",
		"multitool"
	]
}

var completed_events: Dictionary = {}
var progress_dirty: bool = false


func _ready() -> void:
	reset_progress()


# --------------------------------------------------
# RESET
# --------------------------------------------------

func reset_progress() -> void:
	completed_events.clear()
	progress_dirty = false
	progress_changed.emit()


# --------------------------------------------------
# RECORD GAMEPLAY EVENTS
# --------------------------------------------------

func record_event(event_id: String) -> void:
	if event_id.is_empty():
		return

	if completed_events.has(event_id):
		return

	# Remember the previous state before changing anything.
	var previous_unlocked := {}
	var previous_completed := {}

	for quest_id in QUEST_ORDER:
		previous_unlocked[quest_id] = is_quest_unlocked(quest_id)
		previous_completed[quest_id] = is_quest_completed(quest_id)

	completed_events[event_id] = true
	progress_dirty = true

	print("Quest event recorded: ", event_id)

	# Notify about newly completed objectives.
	for quest_id in QUEST_ORDER:
		if not is_quest_unlocked(quest_id):
			continue

		var objectives: Dictionary = QUESTS[quest_id]["objectives"]

		for objective_id in objectives.keys():
			if objectives[objective_id] == event_id:
				objective_completed.emit(
					quest_id,
					str(objective_id)
				)

	# Notify about newly completed quests.
	for quest_id in QUEST_ORDER:
		if not previous_completed[quest_id] \
		and is_quest_completed(quest_id):
			quest_completed.emit(quest_id)

	# Notify about newly unlocked quests.
	for quest_id in QUEST_ORDER:
		if not previous_unlocked[quest_id] \
		and is_quest_unlocked(quest_id):
			quest_unlocked.emit(quest_id)

	progress_changed.emit()


func has_event(event_id: String) -> bool:
	return completed_events.has(event_id)


# --------------------------------------------------
# QUEST UNLOCKING
# --------------------------------------------------

func is_quest_unlocked(quest_id: String) -> bool:
	match quest_id:
		"main":
			return true

		"tutorial":
			return (
				has_event("tutorial_keypad_locked")
				or has_event("tutorial_key_used")
			)

		"elevator":
			return is_quest_completed("tutorial")

		"communications":
			return is_quest_completed("elevator")

	return false


func is_quest_completed(quest_id: String) -> bool:
	if not QUESTS.has(quest_id):
		return false

	if not is_quest_unlocked(quest_id):
		return false

	var objectives: Dictionary = QUESTS[quest_id]["objectives"]

	for objective_id in objectives.keys():
		var event_id: String = objectives[objective_id]

		if not has_event(event_id):
			return false

	return true


# --------------------------------------------------
# OBJECTIVES
# --------------------------------------------------

func get_objective_ids(quest_id: String) -> Array[String]:
	var result: Array[String] = []

	if not OBJECTIVE_ORDER.has(quest_id):
		return result

	for objective_id in OBJECTIVE_ORDER[quest_id]:
		result.append(str(objective_id))

	return result


func is_objective_completed(
	quest_id: String,
	objective_id: String
) -> bool:
	if not QUESTS.has(quest_id):
		return false

	var objectives: Dictionary = QUESTS[quest_id]["objectives"]

	if not objectives.has(objective_id):
		return false

	return has_event(str(objectives[objective_id]))




func is_objective_visible(
	quest_id: String,
	objective_id: String
) -> bool:
	if not is_quest_unlocked(quest_id):
		return false

	if quest_id != "tutorial":
		return true

	match objective_id:
		"find_key":
			return true

		"discover_code":
			# Only appears after inspecting the exposed keypad.
			return has_event("tutorial_keypad_inspected_open")

		"escape":
			# Only appears after entering the correct code.
			return has_event("tutorial_code_discovered")

	return false



func all_objectives_completed(quest_id: String) -> bool:
	return is_quest_completed(quest_id)


# --------------------------------------------------
# QUEST LIST
# --------------------------------------------------

func get_visible_quests() -> Array[String]:
	var result: Array[String] = []

	for quest_id in QUEST_ORDER:
		if is_quest_unlocked(quest_id):
			result.append(quest_id)

	return result


func get_active_quest() -> String:
	# Prioritize the current story quest over the Main Quest.
	for quest_id in QUEST_ORDER:
		if quest_id == "main":
			continue

		if is_quest_unlocked(quest_id) \
		and not is_quest_completed(quest_id):
			return quest_id

	if not is_quest_completed("main"):
		return "main"

	return ""


func get_quest_title(quest_id: String) -> String:
	if not QUESTS.has(quest_id):
		return ""

	return str(QUESTS[quest_id]["title"])


# --------------------------------------------------
# SAVE / LOAD
# --------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"completed_events": completed_events.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	completed_events.clear()

	var events = data.get("completed_events", {})

	if events is Dictionary:
		for event_id in events.keys():
			if events[event_id] == true:
				completed_events[str(event_id)] = true

	progress_dirty = false
	progress_changed.emit()
