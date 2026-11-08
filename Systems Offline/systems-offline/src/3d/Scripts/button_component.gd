extends InteractableComponent

enum ButtonType{
	KEYPAD_BUTTON,
	ELEVATOR_BUTTON
}

@export var button_type: ButtonType

@export_group("Elevator Button")
var active := false
var inside := false
@export var elevator_chamber: Node3D
@export var elevator_door: Node3D
@export var travel_distance: float = 5.0  # Height to travel up in meters
@export var travel_time: float = 5.0     # Time in seconds to reach top
var is_moving: bool = false

@export_group("Keypad Button")
@export var key_value: String
@export var button_mesh: MeshInstance3D
@export var hover_material: Material

func _ready() -> void:
	_setup_audio_players()
	interaction_type = InteractionType.BUTTON

func interact() -> void:
	match button_type:
		ButtonType.KEYPAD_BUTTON:
			keypad_button_interact()
		ButtonType.ELEVATOR_BUTTON:
			elevator_button_interact()

#region Elevator Button Functions
func elevator_button_interact() -> void:
	active = true
	if active and SaveManager.is_puzzle_completed("elevator"):
		Notification.show_message("The elevator is leaving soon! Step inside!", true)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player = body
	inside = true
	move_elevator()

	print("I'm inside ", inside, " and button is pressed ", active)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	inside = false
	print("I'm inside ", inside, " and button is pressed ", active)


func move_elevator() -> void:
	if not elevator_chamber or is_moving:
		return
	if not active or not inside or not SaveManager.is_puzzle_completed("elevator"):
		return
	is_moving = true
	play_primary_se()
	player.disable_controls()
	
	var target_y: float = elevator_chamber.position.y + travel_distance
	var tween: Tween = create_tween()
	
	# Smooth acceleration and deceleration for a realistic elevator feel
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Animate the Y position smoothly
	tween.tween_property(elevator_chamber, "position:y", target_y, travel_time)
	
	# Reset moving state once movement finishes
	tween.finished.connect(func(): is_moving = false)
#endregion

#region Keypad Button Functions
func keypad_button_interact() -> void:
	var keypad = get_parent().get_parent().get_parent()

	if not keypad.is_interacting:
		return

	print("Hit node: ", name, " | key value: ", key_value)
	play_primary_se()
	keypad.press_key(key_value)

func set_hovered(hovered: bool) -> void:
	if hovered:
		button_mesh.material_overlay = hover_material
	else:
		button_mesh.material_overlay = null
#endregion
