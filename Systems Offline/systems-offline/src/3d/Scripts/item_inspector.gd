class_name ItemInspector
extends Control

@onready var item_name_label: Label = $ItemName
@onready var item_description_label: Label = $DescriptionLabel
@onready var inspect_node: Node3D = $SubViewportContainer/SubViewport/PivotNode
@onready var camera: Camera3D = $SubViewportContainer/SubViewport/Camera3D

@export var zoom_speed: float = 0.2
@export var min_zoom: float = 0.5  # Min distance from pivot
@export var max_zoom: float = 3.0  # Max distance from pivot

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
		item_description_label.text = "Description: " + data.description
		
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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(-zoom_speed)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(zoom_speed)
				get_viewport().set_input_as_handled()
		
	if event is InputEventMouseMotion and is_dragging:
		inspect_node.rotate_y(event.relative.x * rotation_sensitivity)
		inspect_node.rotate_object_local(Vector3.RIGHT, event.relative.y * rotation_sensitivity)
		get_viewport().set_input_as_handled()

func _zoom_camera(amount: float) -> void:
	# Adjust camera's Z position relative to the target
	var new_z = camera.position.z + amount
	camera.position.z = clamp(new_z, min_zoom, max_zoom)
