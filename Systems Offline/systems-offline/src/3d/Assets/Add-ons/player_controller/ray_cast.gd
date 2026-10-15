extends RayCast3D


@export_group("HUD")
@export var interaction_label: Label
@export var crosshair: Label
@export var crosshair_view: Control
@export var crosshair_hand: Control
@export var view_label: Control

@onready var player: CharacterBody3D = owner


func _ready() -> void:
	_resolve_hud_references()


func _resolve_hud_references() -> void:
	if crosshair == null:
		crosshair = get_node_or_null("../../../../HUD/Crosshair")
	if crosshair_view == null:
		crosshair_view = get_node_or_null("../../../../HUD/ViewCrosshair")
	if crosshair_hand == null:
		crosshair_hand = get_node_or_null("../../../../HUD/HandCrosshair")
	if interaction_label == null:
		interaction_label = get_node_or_null("../../../../HUD/InteractionLabel")
	if view_label == null:
		view_label = get_node_or_null("../../../../HUD/ViewLabel")

	# Fallback if HUD is located elsewhere in the active scene tree
	var scene_root := get_tree().current_scene if get_tree() else null
	if scene_root:
		var hud := scene_root.find_child("HUD", true, false)
		if hud:
			if crosshair == null:
				crosshair = hud.find_child("Crosshair", true, false)
			if crosshair_view == null:
				crosshair_view = hud.find_child("ViewCrosshair", true, false)
			if crosshair_hand == null:
				crosshair_hand = hud.find_child("HandCrosshair", true, false)
			if interaction_label == null:
				interaction_label = hud.find_child("InteractionLabel", true, false)
			if view_label == null:
				view_label = hud.find_child("ViewLabel", true, false)


func _process(_delta: float) -> void:
	if not player.controls_enabled:
		_hide_all_ui()
		return

	if not is_colliding():
		_reset_ui()
		return

	var hit_obj := get_collider()
	var interactable := _get_interactable_node(hit_obj)

	if interactable == null:
		_reset_ui()
		return

	# Crates have their own interaction message and crosshairs.
	if interactable is InspectComponent and interactable.inspect_type == InspectComponent.InspectType.CRATE:
		if interactable.is_interacting:
			_hide_all_ui()
			return

		if not interactable.open and not interactable.lid_animating:
			# Closed crate: hand palm crosshair and "Press [E] to move"
			_set_ui_state(true, false, true)
			if interaction_label:
				interaction_label.text = interactable.get_interaction_message()
		else:
			# Opened or opening crate: magnifying glass crosshair and "Press [E] to view"
			_set_ui_state(false, true, false)
			if view_label is Label:
				view_label.text = "Press [E] to view"

	# Other inspectable objects keep the existing view prompt.
	elif interactable.interaction_type == InteractableComponent.InteractionType.INSPECT:
		_set_ui_state(false, true, false)
		if view_label is Label:
			view_label.text = "Press [E] to view"

	# All other interactable objects.
	else:
		_set_ui_state(true, false, false)
		if interaction_label:
			if interactable.has_method("get_interaction_message"):
				interaction_label.text = interactable.get_interaction_message()
			else:
				interaction_label.text = "Press [E] to interact"

	if Input.is_action_just_pressed("interact") and interactable.has_method("interact"):
		interactable.interact()


# Helper function to switch UI elements
func _set_ui_state(interact_active: bool, view_active: bool, hand_active: bool = false) -> void:
	if interaction_label:
		interaction_label.visible = interact_active

	if view_label:
		view_label.visible = view_active

	if crosshair_hand:
		crosshair_hand.visible = hand_active
		if crosshair:
			crosshair.visible = interact_active and not hand_active
	else:
		if crosshair:
			crosshair.visible = interact_active or hand_active
			crosshair.text = "✋" if hand_active else "."

	if crosshair_view:
		crosshair_view.visible = view_active


# Resets UI to default crosshair state when not targeting anything interactable
func _reset_ui() -> void:
	if interaction_label:
		interaction_label.visible = false
	if view_label:
		view_label.visible = false
	if crosshair:
		crosshair.visible = true
		crosshair.text = "."
	if crosshair_view:
		crosshair_view.visible = false
	if crosshair_hand:
		crosshair_hand.visible = false


# Hides all HUD elements (e.g. during cutscenes or menu states)
func _hide_all_ui() -> void:
	if interaction_label:
		interaction_label.visible = false
	if view_label:
		view_label.visible = false
	if crosshair:
		crosshair.visible = false
		crosshair.text = "."
	if crosshair_view:
		crosshair_view.visible = false
	if crosshair_hand:
		crosshair_hand.visible = false


# Traverses up to find the node holding the interactable script if colliding with a child CollisionShape
func _get_interactable_node(node: Node) -> Node:
	if node == null:
		return null
	if "interaction_type" in node or node.has_method("interact"):
		return node
	return _get_interactable_node(node.get_parent())
