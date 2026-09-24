class_name InteractableComponent
extends Node

enum InteractionType{
	PICKUP,
	INSPECT,
	UNLOCKABLE,
	KEYPAD,
	KNOB
}

# Select specific object reference and interaction type (set to pickup)
@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.PICKUP
@export var player: CharacterBody3D
@export var player_camera: Camera3D
@export var transition_camera: Camera3D

#region Pickup Variables
@export_group("PickUp")
@export var item_data: ItemData
var can_interact: bool = true
var is_interacting: bool = false 
var is_transitioning := false
@export var pickup_message: Label
#endregion


#region Knob Specific Variables
@export_group("Knob")
@export var rotation_speed : float = 0.05
#endregion
#region Sound Effects Variables
@export_group("Sound Effects")
var primary_audio_player: AudioStreamPlayer3D
var secondary_audio_player: AudioStreamPlayer3D
var tertiary_audio_player: AudioStreamPlayer3D

@export var primary_se: AudioStream
@export var secondary_se: AudioStream
@export var tertiary_se: AudioStream
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	match interaction_type:
		InteractionType.PICKUP:
			pass

func interact() -> void:
	match interaction_type:
		InteractionType.PICKUP: 
			print("Object has been picked up!")
			Inventory.add_item(item_data)
			if Inventory.has_item("7"):
				print("It has this item!")
			queue_free()
			object_ref.visible = false
		InteractionType.INSPECT:
			pass
		InteractionType.UNLOCKABLE:
			pass

func transition(from: Camera3D, target: Camera3D) -> void:
	if is_transitioning:
		return

	is_transitioning = true

	transition_camera.global_transform = from.global_transform
	transition_camera.make_current()

	# Create the tween
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		transition_camera,
		"global_transform",
		target.global_transform,
		0.5
	)

	await tween.finished

	# Target camera takes over
	target.make_current()

	is_transitioning = false



func _unhandled_input(event: InputEvent) -> void:
	if not is_interacting or is_transitioning:
		return

	#if event.is_action_pressed("ui_cancel") and InteractionType.INSPECT:
		#exit_inspect()
		#get_viewport().set_input_as_handled()
		#return

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
