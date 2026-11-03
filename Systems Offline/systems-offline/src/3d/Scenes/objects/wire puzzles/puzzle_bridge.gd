class_name PuzzleBridge
extends Node3D

signal bridge_connected(socket_a: WireSocket, socket_b: WireSocket)
signal bridge_disconnected

@export_group("Interaction")
@export var puzzle_camera: Camera3D
@export var drag_smoothing := 18.0
@export var return_speed := 8.0
@export var snap_distance := 0.3
@export var allow_unplug := true

@export_group("Socket Settings")
@export var required_id_1 := 0
@export var required_id_2 := 0
## If true, the bridge can be flipped 180 degrees to fit into sockets either way.
@export var allow_flipping := true

@export_group("Animation")
@export var animation_duration := 0.5

@export_group("Shader")
@export var core_shader: Shader

@onready var end_1: Area3D = $End1
@onready var end_2: Area3D = $End2
@onready var core_mesh: MeshInstance3D = $GlowingCore

var core_material: ShaderMaterial
var is_dragging := false
var is_connected := false
var is_returning := false

var connected_socket_1: WireSocket
var connected_socket_2: WireSocket

var original_transform: Transform3D
var drag_plane: Plane
var anim_tween: Tween
var _grab_offset := Vector3.ZERO


func _ready() -> void:
	add_to_group("puzzle_bridges")
	original_transform = global_transform

	# Setup click detection on BOTH ends so the player can grab either side
	if end_1 != null:
		end_1.input_ray_pickable = true
		end_1.input_event.connect(_on_end_input_event)
	if end_2 != null:
		end_2.input_ray_pickable = true
		end_2.input_event.connect(_on_end_input_event)

	# Setup drag plane using the bridge's upward axis
	var normal := global_transform.basis.y.normalized()
	drag_plane = Plane(normal, normal.dot(global_position))

	if core_shader != null:
		core_material = ShaderMaterial.new()
		core_material.shader = core_shader
		core_material.set_shader_parameter("progress", 0.0)
		core_material.render_priority = -1
		if core_mesh != null:
			core_mesh.material_override = core_material

	if core_mesh != null:
		core_mesh.visible = false


func _process(delta: float) -> void:
	if not is_connected:
		if is_dragging:
			_drag_to_mouse(delta)
		elif is_returning:
			_return_to_start(delta)


# ---------------------------------------------------------------- Input & Dragging

func _on_end_input_event(
	_camera: Node, event: InputEvent,
	_position: Vector3, _normal: Vector3, _shape_idx: int
) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	if is_connected:
		if not allow_unplug:
			return
		
		# 1. Unplug first (clears sockets, turns off lights, emits signal)
		unplug()
		
		# 2. Immediately grab and start dragging it!
		var hit = _mouse_plane_hit()
		_grab_offset = (global_position - (hit as Vector3)) if hit != null else Vector3.ZERO
		is_dragging = true
		is_returning = false
		return

	var hit = _mouse_plane_hit()
	_grab_offset = (global_position - (hit as Vector3)) if hit != null else Vector3.ZERO

	is_dragging = true
	is_returning = false

func _input(event: InputEvent) -> void:
	if not is_dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		if not _try_connect_both():
			is_returning = true


func _mouse_plane_hit() -> Variant:
	var camera := puzzle_camera if puzzle_camera != null else get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	return drag_plane.intersects_ray(
		camera.project_ray_origin(mouse), camera.project_ray_normal(mouse)
	)


func _drag_to_mouse(delta: float) -> void:
	var hit = _mouse_plane_hit()
	if hit == null:
		return

	var target: Vector3 = (hit as Vector3) + _grab_offset
	var alpha: float = 1.0 - exp(-maxf(drag_smoothing, 0.0) * delta)
	global_position = global_position.lerp(target, alpha)


func _return_to_start(delta: float) -> void:
	global_transform = global_transform.interpolate_with(original_transform, return_speed * delta)
	if global_transform.origin.distance_squared_to(original_transform.origin) < 0.000025:
		global_transform = original_transform
		is_returning = false


# ---------------------------------------------------------------- Snapping & Connecting

func _try_connect_both() -> bool:
	var sockets := get_tree().get_nodes_in_group("wire_sockets")
	print("--- Trying to connect bridge ---")
	print("Total sockets found in group 'wire_sockets': ", sockets.size())
	
	var s1: WireSocket = null
	var s2: WireSocket = null
	var best_dist := INF

	# Check Standard Orientation: End1 -> required_id_1, End2 -> required_id_2
	for node1 in sockets:
		if not node1 is WireSocket:
			print("Node is not a WireSocket: ", node1.name)
			continue
			
		var socket1: WireSocket = node1
		print("Checking socket1: ", socket1.name, " | ID: ", socket1.socket_id, " | Occupied: ", socket1.occupied)
		
		if not socket1.can_connect(required_id_1):
			print(" -> Cannot connect to socket1 (ID mismatch or already occupied)")
			continue
			
		var dist1 = end_1.global_position.distance_to(socket1.get_snap_position())
		print(" -> Distance from End1 to ", socket1.name, ": ", dist1, " (Max allowed: ", snap_distance, ")")
		
		if dist1 > snap_distance:
			continue
			
		for node2 in sockets:
			if node2 == node1 or not node2 is WireSocket:
				continue
				
			var socket2: WireSocket = node2
			if not socket2.can_connect(required_id_2):
				continue
				
			var dist2 = end_2.global_position.distance_to(socket2.get_snap_position())
			print(" ---> Distance from End2 to socket2 (", socket2.name, "): ", dist2)
			
			if dist2 <= snap_distance and (dist1 + dist2) < best_dist:
				best_dist = dist1 + dist2
				s1 = socket1
				s2 = socket2

	if s1 != null and s2 != null:
		print("SUCCESS: Connecting bridge between ", s1.name, " and ", s2.name)
		connect_bridge(s1, s2)
		return true
	else:
		print("FAIL: No valid pair of sockets found within snap distance.")
		return false


func connect_bridge(socket_a: WireSocket, socket_b: WireSocket) -> void:
	connected_socket_1 = socket_a
	connected_socket_2 = socket_b
	is_connected = true
	is_dragging = false
	is_returning = false

	socket_a.connect_wire()
	socket_b.connect_wire()

	# Align bridge so End 1 lands precisely on socket_a
	var offset = socket_a.get_snap_position() - end_1.global_position
	global_position += offset

	animate_core_light(true)
	bridge_connected.emit(socket_a, socket_b)


func unplug() -> void:
	if not is_connected:
		return
	if connected_socket_1 != null:
		connected_socket_1.disconnect_wire()
		connected_socket_1 = null
	if connected_socket_2 != null:
		connected_socket_2.disconnect_wire()
		connected_socket_2 = null

	is_connected = false
	animate_core_light(false)
	bridge_disconnected.emit()


func reset_bridge() -> void:
	unplug()
	global_transform = original_transform
	is_returning = false


# ---------------------------------------------------------------- Lighting Animation

func animate_core_light(turn_on: bool) -> void:
	if anim_tween and anim_tween.is_running():
		anim_tween.kill()

	if turn_on:
		if core_mesh != null:
			core_mesh.visible = true
		if core_material == null:
			return
		var current: float = float(core_material.get_shader_parameter("progress"))
		anim_tween = create_tween()
		anim_tween.tween_method(_set_shader_progress, current, 1.0, animation_duration)
		anim_tween.tween_callback(func():
			if connected_socket_1 and connected_socket_1.light_socket:
				connected_socket_1.light_socket.visible = true
			if connected_socket_2 and connected_socket_2.light_socket:
				connected_socket_2.light_socket.visible = true
		)
	else:
		if core_material == null:
			if core_mesh: core_mesh.visible = false
			return
		var current: float = float(core_material.get_shader_parameter("progress"))
		anim_tween = create_tween()
		anim_tween.tween_method(_set_shader_progress, current, 0.0, animation_duration * 0.5)
		anim_tween.tween_callback(func(): 
			if core_mesh: core_mesh.visible = false
		)


func _set_shader_progress(value: float) -> void:
	if core_material != null:
		core_material.set_shader_parameter("progress", value)
