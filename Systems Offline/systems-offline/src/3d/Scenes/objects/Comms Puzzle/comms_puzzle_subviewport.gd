class_name SubViewportScreen
extends StaticBody3D
## Put on the StaticBody3D whose collider covers the screen. Forwards mouse
## input to the SubViewport that is displayed on `screen_mesh`.

@export var sub_viewport: SubViewport
@export var screen_mesh: MeshInstance3D
## Toggle these if the click lands mirrored / rotated.
@export var flip_u := false
@export var flip_v := false
@export var swap_uv := false

var enabled := false
var _held := false
var _last_pos := Vector2.ZERO





@export var inspect: InspectComponent
@export var puzzle: DialPuzzle2D

func _ready() -> void:
	input_ray_pickable = true
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)

	if inspect == null:
		push_error("SubViewportScreen: assign 'inspect' on " + name)
		return
	inspect.monitor_entered.connect(_on_monitor_entered)
	inspect.monitor_exited.connect(_on_monitor_exited)
	if puzzle:
		puzzle.solved.connect(_on_solved)

func _on_monitor_entered() -> void:
	print("monitor entered")
	enabled = true
	if puzzle:
		puzzle.activate()

func _on_monitor_exited() -> void:
	enabled = false
	if puzzle:
		puzzle.deactivate()

func _on_solved() -> void:
	await get_tree().create_timer(1.0).timeout
	inspect.exit_monitor()
	print("Puzzle solved ", SaveManager.dial_puzzle_completed)


func _on_input_event(_cam, event, world_pos, _n, _i) -> void:
	if not enabled or not event is InputEventMouse:
		return
	var p := _to_viewport_pos(world_pos)
	if not enabled or not event is InputEventMouse:
		return
	_last_pos = p
	var ev: InputEventMouse = event.duplicate()
	ev.position = p
	ev.global_position = p
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_held = ev.pressed
	sub_viewport.push_input(ev, true)


# Releasing the button off the screen would otherwise leave the dial stuck dragging.
func _input(event: InputEvent) -> void:
	if enabled and _held and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_held = false
		var ev: InputEventMouseButton = event.duplicate()
		ev.position = _last_pos
		ev.global_position = _last_pos
		sub_viewport.push_input(ev, true)


func _to_viewport_pos(world_pos: Vector3) -> Vector2:
	var local := screen_mesh.global_transform.affine_inverse() * world_pos
	var aabb := screen_mesh.get_aabb()
	var axes: Array[int] = [0, 1, 2]
	axes.erase(aabb.size.min_axis_index())   # drop the thin axis
	var ua := axes[0]
	var va := axes[1]
	if swap_uv:
		var t := ua
		ua = va
		va = t
	var u := (local[ua] - aabb.position[ua]) / aabb.size[ua]
	var v := (local[va] - aabb.position[va]) / aabb.size[va]
	if flip_u: u = 1.0 - u
	if flip_v: v = 1.0 - v
	return Vector2(u, v) * Vector2(sub_viewport.size)
