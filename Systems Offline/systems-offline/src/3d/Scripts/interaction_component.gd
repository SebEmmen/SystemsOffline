class_name InteractableComponent
extends Node

enum InteractionType{
	PICKUP,
	INSPECT,
	UNLOCKABLE,
	KEYPAD,
	BUTTON,
	TURNABLE
}

# Select specific object reference and interaction type (set to pickup)
@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.PICKUP
@export var player: CharacterBody3D
@export var player_camera: Camera3D
@export var transition_camera: Camera3D
var can_interact: bool = true
var is_interacting: bool = false 
var is_transitioning := false

#region Pickup Variables
@export_group("PickUp")
@export var item_data: ItemData
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
	_setup_audio_players()
	match interaction_type:
		InteractionType.PICKUP:
			pass

# Dynamically instantiates AudioStreamPlayer3D nodes for assigned streams
func _setup_audio_players() -> void:
	if primary_se:
		primary_audio_player = AudioStreamPlayer3D.new()
		primary_audio_player.stream = primary_se
		add_child(primary_audio_player)

	if secondary_se:
		secondary_audio_player = AudioStreamPlayer3D.new()
		secondary_audio_player.stream = secondary_se
		add_child(secondary_audio_player)

	if tertiary_se:
		tertiary_audio_player = AudioStreamPlayer3D.new()
		tertiary_audio_player.stream = tertiary_se
		add_child(tertiary_audio_player)

#region Audio Helper Functions
func play_primary_se() -> void:
	if primary_audio_player:
		primary_audio_player.play()

func play_secondary_se() -> void:
	if secondary_audio_player:
		secondary_audio_player.play()

func play_tertiary_se() -> void:
	if tertiary_audio_player:
		tertiary_audio_player.play()
#endregion

func interact() -> void:
	match interaction_type:
		InteractionType.PICKUP: 
			print("Object has been picked up!")
			Notification.show_pickup_notification(item_data)
			Inventory.add_item(item_data)
			if Inventory.has_item("tutorial_key"):
				print("You found a key! Press tab and inspect it!")
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



func _unhandled_input(_event: InputEvent) -> void:
	if not is_interacting or is_transitioning:
		return

	#if event.is_action_pressed("ui_cancel") and InteractionType.INSPECT:
		#exit_inspect()
		#get_viewport().set_input_as_handled()
		#return

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
