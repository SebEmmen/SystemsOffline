class_name PuzzleBoxSubViewportScreen
extends StaticBody3D
## On the StaticBody3D whose collider covers the screen. Forwards mouse input
## to the SubViewport displayed on `screen_mesh`.

@export_range(0, 3) var rotation_steps := 3   ## match the shader
@export var sub_viewport: SubViewport
@export var screen_mesh: MeshInstance3D
@export var inspect: InspectComponent
@export var puzzle: MathPuzzle2D

@export_group("Click mapping")
## Toggle these if the click lands mirrored / rotated.
@export var flip_u := false
@export var flip_v := false
@export var swap_uv := false
## Turn on if you use Size 2D Override and clicks land at the wrong scale.
@export var use_2d_override_scale := false

@export_group("Other")
@export var exit_delay := 1.0
@export var debug := true

var enabled := false
var _held := false
var _last_pos := Vector2.ZERO


func _ready() -> void:
	input_ray_pickable = true
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)

	if sub_viewport == null or screen_mesh == null:
		push_error("PuzzleBoxSubViewportScreen: assign 'sub_viewport' and 'screen_mesh' on " + name)
		return

	if puzzle:
		puzzle.solved.connect(_on_solved)
	else:
		push_warning("PuzzleBoxSubViewportScreen: 'puzzle' not assigned on " + name)

	if inspect:
		inspect.monitor_entered.connect(_on_monitor_entered)
		inspect.monitor_exited.connect(_on_monitor_exited)
	else:
		push_error("PuzzleBoxSubViewportScreen: assign 'inspect' on " + name)

	if debug:
		print("[Screen] ready. viewport=%s size=%s inspect=%s puzzle=%s" % [sub_viewport, sub_viewport.size, inspect, puzzle])


func _on_monitor_entered() -> void:
	enabled = true
	if debug: print("[Screen] monitor ENTERED")
	if puzzle:
		puzzle.activate()


func _on_monitor_exited() -> void:
	enabled = false
	_held = false
	if debug: print("[Screen] monitor EXITED")
	if puzzle:
		puzzle.deactivate()


func _on_solved() -> void:
	if debug: print("[Screen] puzzle solved")
	await get_tree().create_timer(exit_delay).timeout
	if inspect:
		await inspect.exit_monitor()
		if inspect.has_method("mark_solved"):
			inspect.mark_solved()


func _on_input_event(_cam: Node, event: InputEvent, world_pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if not event is InputEventMouse:
		return

	if debug and event is InputEventMouseButton:
		print("[Screen] ray hit button=%d pressed=%s enabled=%s" % [event.button_index, event.pressed, enabled])

	if not enabled:
		return

	var p := _to_viewport_pos(world_pos)
	_last_pos = p

	if debug and event is InputEventMouseButton and event.pressed:
		print("[Screen]   viewport pos=%s (size %s)" % [p, sub_viewport.size])
		if p.x < 0 or p.y < 0 or p.x > sub_viewport.size.x or p.y > sub_viewport.size.y:
			print("[Screen]   WARNING: outside viewport, try the flip/swap toggles")

	var ev: InputEventMouse = event.duplicate()
	ev.position = p
	ev.global_position = p

	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_held = ev.pressed

	sub_viewport.push_input(ev, true)


# Releasing the button off the screen would otherwise leave a button stuck pressed.
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

	var uv := Vector2(u, v)
	uv -= Vector2(0.5, 0.5)
	for i in rotation_steps:
		uv = Vector2(uv.y, -uv.x)
	uv += Vector2(0.5, 0.5)

	var target := Vector2(sub_viewport.size)
	if use_2d_override_scale and sub_viewport.size_2d_override != Vector2i.ZERO:
		target = Vector2(sub_viewport.size_2d_override)
	return uv * target
