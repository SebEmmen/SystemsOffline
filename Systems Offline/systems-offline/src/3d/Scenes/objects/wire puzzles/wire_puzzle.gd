class_name PuzzleWire
extends Path3D

signal wire_connected(socket: WireSocket)
signal wire_disconnected


@export_group("Appearance")
@export var sag_amount := 0.12
@export var sag_direction := Vector3.FORWARD
@export_range(0.1, 1.0) var start_straightness := 0.55
@export_range(0.05, 0.5) var end_straightness := 0.12

@export_group("Interaction")
@export var puzzle_camera: Camera3D
@export var correct_socket_id := 0
@export var max_wire_length := 2.0
@export var drag_smoothing := 18.0
@export var return_speed := 3.0
## Click a plugged-in connector to pull it back out.
@export var allow_unplug := true

@export_group("Collision")
## Layers that block the wire. Must include the obstacle layer (2)
## AND the layer the connectors (WireEnd) sit on (3)  ->  2 + 4 = 6.
@export_flags_3d_physics var obstacle_mask: int = 6
@export var collision_enabled: bool = true
## Wires closer than this (beyond their radii) count as touching.
@export var wire_clearance := 0.0

@export_group("Boundary")
## Optional hard limit for the container walls. Place a Node3D at the centre of
## the play area (flat in the same plane as the wires) and assign it here.
@export var boundary_node: Node3D
## Size of the allowed area on the boundary node's local X / Z axes.
@export var boundary_size := Vector2(2.0, 1.4)
## Extra gap between the connector's collision box and the edge.
## The box itself is now accounted for, so keep this small.
@export var boundary_padding := 0.02

@export_group("Connector Rotation")
@export var rotate_connector := true
@export var connector_rotation_offset := 0.0 # Degrees
@export var rotation_smoothing := 12.0

@export_group("Animation")
@export var animation_duration := 2.0
## How long the core takes to fade out when the wire is unplugged
## (as a fraction of animation_duration).
@export_range(0.0, 1.0) var lock_fade_ratio := 0.5

@export_group("Layered Wire")
@export_range(0.001, 1.0, 0.001) var glass_radius: float = 0.10
@export_range(0.001, 1.0, 0.001) var core_radius: float = 0.085
@export_range(3, 16) var wire_sides: int = 12
@export var glass_material: Material
@export var core_shader: Shader

@onready var start_point: Marker3D = $StartPoint
@onready var bend_point: Marker3D = $BendPoint
@onready var wire_glass_mesh: MeshInstance3D = $WireGlassMesh
@onready var wire_core_mesh: MeshInstance3D = $WireCoreMesh
@onready var wire_end: Area3D = $WireEnd
@onready var connector_collision: CollisionShape3D = $WireEnd/CollisionShape3D

var core_material: ShaderMaterial

var is_dragging := false
var is_returning := false
var is_plugged := false          # was "is_connected" (shadowed Object.is_connected)
var is_unlocked := false
var connected_socket: WireSocket

var original_end_position: Vector3
var drag_plane: Plane
var unlock_tween: Tween
var _mesh_dirty := true
var _cable_shape := SphereShape3D.new()
var _connector_aabb := AABB()          # connector collision box, in its own local space
var _grab_offset := Vector3.ZERO       # pivot minus mouse hit at the moment of grabbing


func _ready() -> void:
	add_to_group("puzzle_wires")

	if connector_collision != null and connector_collision.shape != null:
		_connector_aabb = connector_collision.shape.get_debug_mesh().get_aabb()

	curve = curve.duplicate(true) if curve != null else Curve3D.new()
	if curve.point_count < 2:
		curve.clear_points()
		curve.add_point(Vector3.ZERO)
		curve.add_point(Vector3(0.6, 0, 0))

	if curve.point_count != 3:
		curve.clear_points()
		curve.add_point(start_point.position)
		curve.add_point(bend_point.position)
		curve.add_point(wire_end.position)
	else:
		curve.set_point_position(0, start_point.position)
		curve.set_point_position(1, bend_point.position)

	original_end_position = curve.get_point_position(2)
	wire_end.position = original_end_position
	wire_end.input_ray_pickable = true
	wire_end.input_event.connect(_on_wire_end_input_event)

	var normal := global_transform.basis.y.normalized()
	drag_plane = Plane(normal, normal.dot(wire_end.global_position))

	if core_shader != null:
		core_material = ShaderMaterial.new()
		core_material.shader = core_shader
		core_material.set_shader_parameter("progress", 0.0)
		# Draw the core before the (transparent) glass so sorting looks right.
		core_material.render_priority = -1

	_update_curve_shape()
	_rebuild_mesh()
	_update_connector_rotation(1.0, true)

	# Core starts invisible (shader alpha is 0 at progress 0 anyway,
	# this just skips rendering a fully transparent mesh).
	wire_core_mesh.visible = false


func _process(delta: float) -> void:
	if not is_plugged:
		if is_dragging:
			_drag_to_mouse(delta)
		elif is_returning:
			_return_to_start(delta)
		_update_connector_rotation(delta)

	if _mesh_dirty:
		_rebuild_mesh()


# ---------------------------------------------------------------- input

func _on_wire_end_input_event(
	_camera: Node, event: InputEvent,
	_position: Vector3, _normal: Vector3, _shape_idx: int
) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if is_plugged:
		if not allow_unplug:
			return
		unplug()

	# Keep the mouse on the spot that was grabbed instead of snapping to the pivot.
	var hit = _mouse_plane_hit()
	_grab_offset = (wire_end.global_position - (hit as Vector3)) if hit != null else Vector3.ZERO

	is_dragging = true
	is_returning = false


func _input(event: InputEvent) -> void:
	if not is_dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		is_returning = not _try_connect_to_socket()


# ------------------------------------------------------------- movement

## Where the mouse ray hits the drag plane (null if it doesn't).
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
	var origin := to_global(curve.get_point_position(0))
	var offset := target - origin
	if max_wire_length > 0.0 and offset.length() > max_wire_length:
		target = origin + offset.normalized() * max_wire_length

	var alpha: float = 1.0 - exp(-maxf(drag_smoothing, 0.0) * delta)
	_move_connector(wire_end.global_position.lerp(target, alpha))


func _return_to_start(delta: float) -> void:
	var target: Vector3 = to_global(original_end_position)
	_move_connector(wire_end.global_position.move_toward(target, return_speed * delta))

	if wire_end.global_position.distance_squared_to(target) < 0.000025:
		_set_endpoint(target)
		is_returning = false


## Moves the connector towards `desired`, but only if the result is legal.
func _move_connector(desired: Vector3) -> void:
	desired = _clamp_to_boundary(desired)

	if not collision_enabled:
		_set_endpoint(desired)
		return

	var previous := wire_end.global_position
	var hits_before := _count_cable_hits()
	var gap_before := _min_gap_to_other_wires()

	_set_endpoint(_get_safe_position(desired))

	# Cable may not move into more obstacles than before...
	var bad := _count_cable_hits() > hits_before
	# ...and may not cross another wire (moving out of an overlap is allowed).
	if not bad:
		var gap_after := _min_gap_to_other_wires()
		bad = gap_after < 0.0 and gap_after < gap_before - 0.0001

	if bad:
		_set_endpoint(previous)


# ------------------------------------------------------ collision helpers

func _make_connector_query(pos: Vector3) -> PhysicsShapeQueryParameters3D:
	var t := connector_collision.global_transform
	t.origin += pos - wire_end.global_position

	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = connector_collision.shape
	q.transform = t
	q.collision_mask = obstacle_mask
	q.collide_with_bodies = true
	q.collide_with_areas = true          # other wires' connectors are Area3Ds!
	q.exclude = [wire_end.get_rid()]
	return q


func _connector_overlaps(pos: Vector3) -> bool:
	var q := _make_connector_query(pos)
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Sweeps the connector from `from` to `to`, returns the furthest safe point.
func _sweep(from: Vector3, to: Vector3) -> Vector3:
	var motion := to - from
	if motion.length_squared() < 0.00000001:
		return from
	var q := _make_connector_query(from)
	q.motion = motion
	var result := get_world_3d().direct_space_state.cast_motion(q)
	if result.size() < 2:
		return from
	return from + motion * maxf(result[0] - 0.001, 0.0)


func _get_safe_position(target: Vector3) -> Vector3:
	if connector_collision == null or connector_collision.shape == null:
		return target

	var current := wire_end.global_position
	# Already overlapping something (bad scene setup)? Let it escape.
	if _connector_overlaps(current):
		return target

	var pos := _sweep(current, target)

	# Slide along surfaces instead of stopping dead.
	var remaining := target - pos
	if remaining.length_squared() > 0.00000001:
		var axes: Array[Vector3] = [
			global_basis.x.normalized(),
			global_basis.z.normalized(),
		]
		for axis in axes:
			pos = _sweep(pos, pos + axis * remaining.dot(axis))
	return pos


## Keeps a world position inside the rectangle defined by boundary_node.
func _clamp_to_boundary(pos: Vector3) -> Vector3:
	if boundary_node == null:
		return pos

	var xf := boundary_node.global_transform
	var inv := xf.affine_inverse()
	var pivot_local: Vector3 = inv * wire_end.global_position
	var target_local: Vector3 = inv * pos

	# How far the connector's collision box reaches around its pivot,
	# measured in the boundary's X/Z axes (uses the current rotation).
	var lo := Vector2.ZERO
	var hi := Vector2.ZERO
	if connector_collision != null and _connector_aabb.has_volume():
		var to_boundary: Transform3D = inv * connector_collision.global_transform
		for i in 8:
			var c: Vector3 = to_boundary * _connector_aabb.get_endpoint(i)
			var rel := Vector2(c.x - pivot_local.x, c.z - pivot_local.z)
			lo = Vector2(minf(lo.x, rel.x), minf(lo.y, rel.y))
			hi = Vector2(maxf(hi.x, rel.x), maxf(hi.y, rel.y))

	var half := boundary_size * 0.5 - Vector2.ONE * boundary_padding
	var min_x := -half.x - lo.x
	var max_x := half.x - hi.x
	var min_z := -half.y - lo.y
	var max_z := half.y - hi.y
	target_local.x = clampf(target_local.x, minf(min_x, max_x), maxf(min_x, max_x))
	target_local.z = clampf(target_local.z, minf(min_z, max_z), maxf(min_z, max_z))
	return xf * target_local


## Pulls the connector out of its socket (without sending it home).
func unplug() -> void:
	if not is_plugged:
		return
	if connected_socket != null:
		connected_socket.disconnect_wire()
		connected_socket = null
	is_plugged = false
	set_locked()
	wire_disconnected.emit()


func _global_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in curve.get_baked_points():
		out.append(to_global(p))
	return out


## Number of cable sample points that touch a static obstacle.
func _count_cable_hits() -> int:
	_cable_shape.radius = glass_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _cable_shape
	q.collision_mask = obstacle_mask
	q.collide_with_bodies = true
	q.collide_with_areas = false

	var space := get_world_3d().direct_space_state
	var hits := 0
	for p in _global_points():
		q.transform = Transform3D(Basis.IDENTITY, p)
		if not space.intersect_shape(q, 1).is_empty():
			hits += 1
	return hits


## Smallest surface gap to any other wire (negative = overlapping).
func _min_gap_to_other_wires() -> float:
	var mine := _global_points()
	var best := INF
	for node in get_tree().get_nodes_in_group("puzzle_wires"):
		if node == self or not node is PuzzleWire:
			continue
		var other: PuzzleWire = node
		var theirs := other._global_points()
		var radii := glass_radius + other.glass_radius + wire_clearance
		for i in range(mine.size() - 1):
			for j in range(theirs.size() - 1):
				var c := Geometry3D.get_closest_points_between_segments(
					mine[i], mine[i + 1], theirs[j], theirs[j + 1]
				)
				best = minf(best, c[0].distance_to(c[1]) - radii)
	return best


# ------------------------------------------------------------ curve/mesh

func _set_endpoint(world_position: Vector3) -> void:
	if wire_end.global_position.distance_squared_to(world_position) < 0.00000001:
		return
	wire_end.global_position = world_position
	curve.set_point_position(curve.point_count - 1, to_local(world_position))
	_update_curve_shape()
	_mesh_dirty = true


func _update_curve_shape() -> void:
	if curve.point_count != 3:
		return

	var start: Vector3 = curve.get_point_position(0)
	var bend: Vector3 = curve.get_point_position(1)
	var end: Vector3 = curve.get_point_position(2)

	var straight_direction: Vector3 = bend - start
	var flex_direction: Vector3 = end - bend
	var flex_length: float = flex_direction.length()

	if straight_direction.length_squared() < 0.000001:
		return
	if flex_length < 0.001:
		return

	curve.set_point_out(0, straight_direction / 3.0)
	curve.set_point_in(1, -straight_direction / 3.0)

	var exit_direction: Vector3 = straight_direction.normalized()
	curve.set_point_out(1, exit_direction * flex_length * start_straightness)

	var end_direction: Vector3 = flex_direction.normalized()
	var end_handle: Vector3 = (
		end_direction * flex_length * end_straightness
		+ sag_direction.normalized() * sag_amount
	)
	curve.set_point_in(2, -end_handle)


func _update_connector_rotation(delta: float, immediate := false) -> void:
	if not rotate_connector or is_plugged:
		return
	var points := curve.get_baked_points()
	if points.size() < 2:
		return

	var direction: Vector3 = points[-1] - points[-2]
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		return

	var target_angle := atan2(-direction.x, -direction.z) + deg_to_rad(connector_rotation_offset)
	var alpha := 1.0 if immediate else 1.0 - exp(-maxf(rotation_smoothing, 0.0) * delta)
	wire_end.rotation.y = lerp_angle(wire_end.rotation.y, target_angle, alpha)


# --------------------------------------------------------------- sockets

func _try_connect_to_socket() -> bool:
	var closest: WireSocket = null
	var closest_distance := INF
	for node in get_tree().get_nodes_in_group("wire_sockets"):
		if not node is WireSocket:
			continue
		var socket: WireSocket = node
		if not socket.can_connect(correct_socket_id):
			continue
		var distance := wire_end.global_position.distance_to(socket.get_snap_position())
		if distance <= socket.snap_distance and distance < closest_distance:
			closest = socket
			closest_distance = distance
	if closest == null:
		return false
	connect_to_socket(closest)
	return true


func connect_to_socket(socket: WireSocket) -> void:
	if is_plugged or socket.occupied:
		return
	connected_socket = socket
	is_plugged = true
	is_dragging = false
	is_returning = false
	socket.connect_wire()
	_set_endpoint(socket.get_snap_position())
	wire_end.global_basis = socket.snap_point.global_basis
	set_unlocked()
	wire_connected.emit(socket)


func reset_wire() -> void:
	if connected_socket != null:
		connected_socket.disconnect_wire()
		connected_socket = null
	is_plugged = false
	is_dragging = false
	is_returning = false
	_set_endpoint(to_global(original_end_position))
	_update_connector_rotation(1.0, true)
	set_locked()
	wire_disconnected.emit()


# ------------------------------------------------------------- mesh build

func _build_wire_mesh(points: PackedVector3Array, radius: float, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])

	var traveled := 0.0

	for i in range(points.size()):
		if i > 0:
			traveled += points[i - 1].distance_to(points[i])

		var tangent: Vector3 = (
			points[i + 1] - points[i]
			if i < points.size() - 1
			else points[i] - points[i - 1]
		).normalized()

		if tangent.length_squared() < 0.000001:
			tangent = Vector3.RIGHT

		var axis := tangent.cross(Vector3.UP)
		if axis.length_squared() < 0.001:
			axis = tangent.cross(Vector3.RIGHT)
		axis = axis.normalized()

		var second := tangent.cross(axis).normalized()

		for j in range(wire_sides):
			var angle := TAU * float(j) / wire_sides
			var offset := (axis * cos(angle) + second * sin(angle)) * radius

			surface.set_uv(Vector2(
				float(j) / wire_sides,
				traveled / maxf(length, 0.0001)
			))
			surface.add_vertex(points[i] + offset)

			if i > 0:
				var a := (i - 1) * wire_sides + j
				var b := (i - 1) * wire_sides + (j + 1) % wire_sides
				var c := i * wire_sides + j
				var d := i * wire_sides + (j + 1) % wire_sides

				surface.add_index(a)
				surface.add_index(b)
				surface.add_index(c)
				surface.add_index(c)
				surface.add_index(b)
				surface.add_index(d)

	surface.generate_normals()
	if material != null:
		surface.set_material(material)
	return surface.commit()


func _rebuild_mesh() -> void:
	_mesh_dirty = false
	var points := curve.get_baked_points()

	if points.size() < 2:
		wire_glass_mesh.mesh = null
		wire_core_mesh.mesh = null
		return

	wire_glass_mesh.mesh = _build_wire_mesh(points, glass_radius, glass_material)
	wire_core_mesh.mesh = _build_wire_mesh(points, core_radius, core_material)


# ---------------------------------------------------------- unlock anim

func set_unlocked() -> void:
	if unlock_tween and unlock_tween.is_running():
		unlock_tween.kill()

	is_unlocked = true
	wire_core_mesh.visible = true
	if core_material == null:
		return

	var current: float = float(core_material.get_shader_parameter("progress"))
	unlock_tween = create_tween()
	unlock_tween.tween_method(_set_wire_progress, current, 1.0, animation_duration)
	unlock_tween.tween_callback(_on_unlock_finished)


func _on_unlock_finished() -> void:
	if connected_socket != null and connected_socket.light_socket != null:
		connected_socket.light_socket.visible = true


func _set_wire_progress(value: float) -> void:
	if core_material != null:
		core_material.set_shader_parameter("progress", value)


func set_locked() -> void:
	if unlock_tween and unlock_tween.is_running():
		unlock_tween.kill()

	is_unlocked = false
	if core_material == null or lock_fade_ratio <= 0.0:
		_set_wire_progress(0.0)
		wire_core_mesh.visible = false
		return

	# The glow retracts along the wire, then the mesh is hidden once it is invisible.
	var current: float = float(core_material.get_shader_parameter("progress"))
	unlock_tween = create_tween()
	unlock_tween.tween_method(_set_wire_progress, current, 0.0, animation_duration * lock_fade_ratio)
	unlock_tween.tween_callback(func(): wire_core_mesh.visible = false)
