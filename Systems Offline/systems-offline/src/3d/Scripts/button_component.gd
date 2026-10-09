extends InteractableComponent

enum ButtonType{
	KEYPAD_BUTTON,
	ELEVATOR_BUTTON
}

@export var button_type: ButtonType

@export_group("Elevator Button")
@export var elevator: Node3D
@export var travel_distance: float = 5.0  # Height to travel up in meters
@export var travel_time: float = 5.0     # Time in seconds to reach top
var is_moving: bool = false

@export_group("Keypad Button")
@export var key_value: String
@export var button_mesh: MeshInstance3D
@export var hover_material: Material

func _ready() -> void:
	interaction_type = InteractionType.BUTTON

func interact() -> void:
	match button_type:
		ButtonType.KEYPAD_BUTTON:
			keypad_button_interact()
		ButtonType.ELEVATOR_BUTTON:
			elevator_button_interact()

#region Elevator Button Functions
func elevator_button_interact() -> void:
	if not elevator or is_moving:
		return

	is_moving = true
	
	var target_y: float = elevator.position.y + travel_distance
	var tween: Tween = create_tween()
	
	# Smooth acceleration and deceleration for a realistic elevator feel
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Animate the Y position smoothly
	tween.tween_property(elevator, "position:y", target_y, travel_time)
	
	# Reset moving state once movement finishes
	tween.finished.connect(func(): is_moving = false)
#endregion

#region Keypad Button Functions
func keypad_button_interact() -> void:
	var keypad = get_parent().get_parent().get_parent()

	if not keypad.is_interacting:
		return

	print("Hit node: ", name, " | key value: ", key_value)
	keypad.press_key(key_value)

func set_hovered(hovered: bool) -> void:
	if hovered:
		button_mesh.material_overlay = hover_material
	else:
		button_mesh.material_overlay = null
#endregion
