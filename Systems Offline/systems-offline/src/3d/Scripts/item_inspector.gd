class_name ItemInspector
extends Control

@onready var item_name_label: Label = $ItemName
@onready var item_description_label: Label = $DescriptionLabel
@onready var inspect_node: Node3D = $SubViewportContainer/SubViewport/PivotNode

@export var rotation_sensitivity: float = 0.005

var is_dragging: bool = false

func _ready() -> void:
	hide()

func setup_inspection(data: ItemData) -> void:
	for child in inspect_node.get_children():
		child.queue_free()
		
	inspect_node.transform.basis = Basis()
	
	if data:
		item_name_label.text = data.item_name
		item_description_label.text = data.description
		
		if data.inspect_scene:
			var item_mesh = data.inspect_scene.instantiate()
			inspect_node.add_child(item_mesh)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		hide()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		get_viewport().set_input_as_handled()
		
	if event is InputEventMouseMotion and is_dragging:
		inspect_node.rotate_y(event.relative.x * rotation_sensitivity)
		inspect_node.rotate_object_local(Vector3.RIGHT, event.relative.y * rotation_sensitivity)
		get_viewport().set_input_as_handled()
