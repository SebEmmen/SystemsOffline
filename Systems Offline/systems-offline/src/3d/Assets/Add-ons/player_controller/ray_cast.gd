extends RayCast3D


@export_group("HUD")
@export var interaction_label: Label
@export var crosshair : Label
@export var crosshair_view : Control
@export var view_label : Control

@onready var player: CharacterBody3D = owner


func _process(_delta: float) -> void:
	if not player.controls_enabled:
		interaction_label.visible = false
		return
		

	if is_colliding():
		var hit_obj = get_collider()
		
		var interactable = _get_interactable_node(hit_obj)
		
		if interactable == null:
			_reset_ui()
			return

		if interactable:
			# Check if the object is set to INSPECT mode
			if interactable.interaction_type == InteractableComponent.InteractionType.INSPECT:
				_set_ui_state(false, true)
			else:
				_set_ui_state(true, false)
		else:
			_reset_ui()
		if Input.is_action_just_pressed("interact") and interactable.has_method("interact"):
					interactable.interact()
	else:
		_reset_ui()

# Helper function to switch UI elements
func _set_ui_state(interact_active: bool, view_active: bool) -> void:
	interaction_label.visible = interact_active
	crosshair.visible = interact_active
	
	view_label.visible = view_active
	crosshair_view.visible = view_active

# Resets UI to default crosshair state when not targeting anything interactable
func _reset_ui() -> void:
	interaction_label.visible = false
	view_label.visible = false
	crosshair.visible = true
	crosshair_view.visible = false

# Hides all HUD elements (e.g. during cutscenes or menu states)
func _hide_all_ui() -> void:
	interaction_label.visible = false
	view_label.visible = false
	crosshair.visible = false
	crosshair_view.visible = false

# Traverses up to find the node holding the interactable script if colliding with a child CollisionShape
func _get_interactable_node(node: Node) -> Node:
	if node == null:
		return null
	if "interaction_type" in node or node.has_method("interact"):
		return node
	return _get_interactable_node(node.get_parent())
