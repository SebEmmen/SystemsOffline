
@tool
extends Node3D

@export var preview_enabled: bool = false

@export_enum("Start", "Insert", "Turn", "Hanger")
var preview_position: int = 0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(true)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	if not preview_enabled:
		return

	var key: Node3D = get_node_or_null("AnimatedKey")

	if key == null:
		return

	var markers := [
		get_node_or_null("KeyStart"),
		get_node_or_null("KeyInsert"),
		get_node_or_null("KeyTurn"),
		get_node_or_null("KeyHangerTarget")
	]

	var target: Marker3D = markers[preview_position]

	if target == null:
		return

	key.visible = true
	key.global_transform = target.global_transform
