class_name InspectComponent
extends InteractableComponent


enum InspectType{
	POSTER,
	CRATE,
	WIRES_PUZZLE,
	MONITOR
	}


	
@export var inspect_type: InspectType
#region Inspect Variables
@export_group("Inspect")
@export var inspect_camera : Camera3D
#endregion

#region Poster Variable
@export_group("Poster")
var default_font: Font = ThemeDB.fallback_font
@export var alien_language_screen: MeshInstance3D
@export var human_language_screen: MeshInstance3D
@export var poster_text: Label3D
#endregion

#region Crate Variables
@export_group("Crate")
@export var number_label: Label3D
@export var number : String = "0"
@export var crate_lid: Node3D
@export var lid_target: Marker3D

@onready var lid_position: Vector3 
@onready var lid_rotation: Vector3
@onready var open:= false

var lid_animating: bool = false
#endregion

#region Wires_Puzzle Variable
@export_group("Wires_Puzzle")
@export var puzzle_overlay_scene: PackedScene
@export_file("*.tscn") var puzzle_scene: String = "res://src/3d/Scenes/objects/wire puzzles/WirePuzzleComms.scn"
@export var puzzle_id: String = ""
@export var power_off: Node3D
@export var power_on: Node3D
@export var elevator_on: MeshInstance3D
@export var elevator_off: MeshInstance3D
@export var wire_cover: RigidBody3D

var cover_home: Transform3D
var fixed: bool = false

var cover_removed: bool = false
var cover_drop_time: float = 0.0

var puzzle_layer: CanvasLayer
var puzzle_viewport: SubViewport
var puzzle_instance: Node
#endregion

#region Monitor Variables
@export_group("Monitor")
## The dial(s) on this monitor
@export var lightning_off: Node3D
@export var main_screen: MeshInstance3D
@export var side_screen: MeshInstance3D


signal monitor_entered
signal monitor_exited

var monitor_active := false
#endregion
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_audio_players()
	match inspect_type:
		InspectType.POSTER:
			pass
		InspectType.CRATE:
			ready_crate()
		InspectType.WIRES_PUZZLE:
			ready_puzzle()
		InspectType.MONITOR:
			update_monitor()
			SaveManager.puzzle_completed.connect(func(_id): update_monitor())
			pass

func interact() -> void:
	if not can_interact:
		return

	match inspect_type:
		InspectType.POSTER:
			inspect_poster()

		InspectType.CRATE:
			if is_interacting or is_transitioning:
				return

			if not open and not lid_animating:
				open_crate()
			else:
				enter_crate()
		
		InspectType.WIRES_PUZZLE:
			if puzzle_id == "elevator" and not SaveManager.dial_puzzle_completed:
				Notification.show_message("You cannot open it yet...", true)
				await get_tree().create_timer(1.0).timeout
				Notification.hide_message()
				return
			enter_puzzle()
		InspectType.MONITOR:
			enter_monitor()


#region Inspect Functions

#func interact_inspect() -> void:
	#object_ref.enter_inspect()


func enter_inspect() -> void:
	if is_interacting or is_transitioning:
		return
	is_interacting = true
	
	player.disable_controls()
	player.visible = false

	# Hide mouse AFTER disabling controls
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	await get_tree().process_frame
	await transition(player_camera, inspect_camera)




func exit_inspect() -> void:
	if not is_interacting or is_transitioning:
		return


	await transition(inspect_camera, player_camera)
	player.visible = true

	is_interacting = false

	await get_tree().process_frame
	player.enable_controls()



func get_interaction_message() -> String:
	match inspect_type:
		InspectType.CRATE:
			if not open and not lid_animating:
				return "Press [E] to move"
			return "Press [E] to view"

		InspectType.POSTER:
			return "Press [E] to view"
		
	return "Press [E] to interact"



#endregion

#region Crate Functions

func ready_crate() -> void:
	if number_label:
		number_label.text = number
	elif inspect_type == InspectType.CRATE:
		push_warning("InspectComponent: 'number_label' is not assigned on " + name)
		
	if crate_lid:
		lid_position = crate_lid.position
		lid_rotation = crate_lid.rotation
	elif inspect_type == InspectType.CRATE:
		push_warning("InspectComponent: 'crate_lid' is not assigned on " + name)

func place_lid_next() -> void:
	if crate_lid == null or lid_target == null:
		return

	var tween_lid := create_tween()
	tween_lid.set_parallel(true)

	tween_lid.tween_property(
		crate_lid,
		"global_position",
		lid_target.global_position,
		0.5
	)

	tween_lid.tween_property(
		crate_lid,
		"global_rotation",
		lid_target.global_rotation,
		0.5
	)

	await tween_lid.finished




func enter_crate() -> void:
	if not open and not lid_animating:
		return

	if is_interacting or is_transitioning:
		return

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	await enter_inspect()


	


func exit_crate() -> void:
	if not is_interacting or is_transitioning:
		return

	await exit_inspect()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func open_crate() -> void:
	play_primary_se()
	if open or lid_animating:
		return

	if crate_lid == null or lid_target == null:
		return

	open = true
	lid_animating = true

	# Position tween: X first, then Y.
	var position_tween := create_tween()
	position_tween.set_trans(Tween.TRANS_QUAD)
	position_tween.set_ease(Tween.EASE_IN_OUT)

	position_tween.tween_property(
		crate_lid,
		"position:x",
		lid_target.position.x,
		0.5
	)

	position_tween.tween_property(
		crate_lid,
		"position:y",
		lid_target.position.y,
		0.9
	)


	var rotation_tween := create_tween()

	rotation_tween.set_trans(Tween.TRANS_QUINT)
	rotation_tween.set_ease(Tween.EASE_IN_OUT)

	rotation_tween.tween_property(
		crate_lid,
		"rotation",
		lid_target.rotation,
		1.4
	)

	await position_tween.finished
	await rotation_tween.finished

	lid_animating = false


#endregion

#region Poster Functions

func inspect_poster() -> void:
	if is_interacting or is_transitioning:
		return

	is_interacting = true
	if SaveManager.is_multitool_part_complete("comms_upgrade"):
		translate()
	player.disable_controls()
	player.visible = false

	# Visible so the player can see and use the cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await get_tree().process_frame
	await transition(player_camera, inspect_camera)
	

func exit_poster() -> void:
	if not is_interacting or is_transitioning:
		return

	await transition(inspect_camera, player_camera)
	player.visible = true

	is_interacting = false
	if SaveManager.is_multitool_part_complete("comms_upgrade"):
		translate()
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	player.enable_controls()
	

func translate() -> void:
	if is_interacting:
		alien_language_screen.visible = false
		human_language_screen.visible = true
	else:
		human_language_screen.visible = false
		alien_language_screen.visible = true

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and poster_text and default_font:
		poster_text.font = default_font


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		pass
#endregion
#endregion

#region Wires Puzzle Functions
func ready_puzzle() -> void:
	if puzzle_id == "":
		push_warning("InspectComponent: puzzle_id not set on " + name)

	fixed = SaveManager.is_puzzle_completed(puzzle_id)
	cover_removed = SaveManager.is_cover_removed(puzzle_id)

	if wire_cover:
		cover_home = wire_cover.global_transform   # original spot on the panel
		if fixed:
			wire_cover.freeze = true
			cover_removed = false
		elif cover_removed:
			var saved := SaveManager.get_cover_transform(puzzle_id)
			var s := wire_cover.global_transform.basis.get_scale()
			wire_cover.global_transform = Transform3D(saved.basis.scaled(s), saved.origin)
			wire_cover.freeze = true

	can_interact = not fixed
	if power_on:
		power_on.visible = fixed
	if power_off:
		power_off.visible = not fixed

	if elevator_on and elevator_off:
		elevator_on.visible = fixed
		elevator_off.visible = not fixed	

func _return_cover() -> void:
	if wire_cover == null:
		return
	cover_removed = false
	wire_cover.freeze = true
	wire_cover.linear_velocity = Vector3.ZERO
	wire_cover.angular_velocity = Vector3.ZERO

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(wire_cover, "global_transform", cover_home, 0.6)

func _open_puzzle_viewport() -> void:
	puzzle_layer = puzzle_overlay_scene.instantiate()
	puzzle_viewport = puzzle_layer.get_node("SubViewportContainer/SubViewport")

	puzzle_instance = (load(puzzle_scene) as PackedScene).instantiate()
	puzzle_viewport.add_child(puzzle_instance)

	var emitter := _find_puzzle_emitter(puzzle_instance)
	if emitter == null:
		push_error("No node with puzzle_completed found in " + puzzle_scene)
	else:
		print("Connecting to puzzle script on: ", emitter.get_path())
		emitter.puzzle_completed.connect(_on_puzzle_completed)
		emitter.puzzle_exited.connect(exit_wires_puzzle)

	print("overlay: ", puzzle_overlay_scene, " | scene: ", puzzle_scene)
	print("emitter: ", emitter)
	get_tree().root.add_child(puzzle_layer)
	print("overlay in tree: ", puzzle_layer.is_inside_tree())

func _find_puzzle_emitter(root: Node) -> Node:
	if root.has_signal("puzzle_completed"):
		return root
	for child in root.find_children("*", "", true, false):
		if child.has_signal("puzzle_completed"):
			return child
	return null

func enter_puzzle() -> void:
	if is_interacting or is_transitioning:
		return
	if wire_cover and not cover_removed:
		cover_removed = true
		cover_drop_time = Time.get_ticks_msec() / 1000.0
		wire_cover.fall_off()
		play_primary_se()
		return

	# Cover still falling: ignore the press
	if not _cover_is_settled():
		return

	is_interacting = true
	player.disable_controls()
	if wire_cover:
		SaveManager.set_cover_transform(puzzle_id, wire_cover.global_transform)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open_puzzle_viewport()

func _cover_is_settled() -> bool:
	if wire_cover == null:
		return true
	var elapsed := Time.get_ticks_msec() / 1000.0 - cover_drop_time
	return elapsed > 0.5 and (wire_cover.sleeping or wire_cover.linear_velocity.length() < 0.05)

func exit_wires_puzzle() -> void:
	print("exit_wires_puzzle, is_interacting = ", is_interacting)
	if not is_interacting:
		return

	if puzzle_layer:
		puzzle_layer.queue_free()
		puzzle_layer = null
		puzzle_viewport = null
		puzzle_instance = null

	is_interacting = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SaveManager.save_game()
	await get_tree().process_frame
	player.enable_controls()

func _on_puzzle_completed() -> void:
	SaveManager.complete_puzzle(puzzle_id)
	fixed = true
	can_interact = false
	if power_on:
		power_on.visible = true
	if power_off:
		power_off.visible = false
	if elevator_on and elevator_off:
		elevator_on.visible = true
		elevator_off.visible = false
	exit_wires_puzzle()
	_return_cover()


#endregion

#region Monitor Functions

func enter_monitor() -> void:
	if is_interacting or is_transitioning:
		return

	is_interacting = true
	player.disable_controls()
	player.visible = false

	# Visible so the player can see and use the cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await get_tree().process_frame
	await transition(player_camera, inspect_camera)

	monitor_active = true
	monitor_entered.emit()

func update_monitor() -> void:
	if SaveManager.is_puzzle_completed("comms"):
		main_screen.visible = true
		if side_screen:
			side_screen.visible = true
		lightning_off.visible = false
	else:
		main_screen.visible = false
		if side_screen:
			side_screen.visible = false
		lightning_off.visible = true

func exit_monitor() -> void:
	if not monitor_active or is_transitioning:
		return

	monitor_active = false
	monitor_exited.emit()

	await transition(inspect_camera, player_camera)
	player.visible = true
	is_interacting = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	player.enable_controls()
#endregion
func _input(event: InputEvent) -> void:
	if not is_interacting or is_transitioning:
		return

	if inspect_type == InspectType.WIRES_PUZZLE:
		if event.is_action_pressed("ui_cancel"):
			exit_wires_puzzle()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		match inspect_type:
			InspectType.CRATE:
				exit_crate()
				get_viewport().set_input_as_handled()
			InspectType.POSTER:
				exit_poster()
				get_viewport().set_input_as_handled()
			InspectType.MONITOR:
				exit_monitor()
				get_viewport().set_input_as_handled()
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
