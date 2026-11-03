class_name WirePuzzleStationary
extends Path3D

@export_group("Appearance")
@export var sag_amount := 0.1
@export var sag_direction := Vector3.FORWARD
@export_range(0.1, 1.0) var start_straightness := 0.55
@export_range(0.05, 0.5) var end_straightness := 0.12

@export_group("State")
## If true, the core starts fully lit on ready. If false, it starts hidden/unlit.
@export var core_on_by_default: bool = false

@export_group("Animation")
@export var animation_duration := 0.5

@export_group("Layered Wire")
@export_range(0.001, 1.0, 0.001) var glass_radius: float = 0.25
@export_range(0.001, 1.0, 0.001) var core_radius: float = 0.22
@export_range(3, 16) var wire_sides: int = 10
@export var glass_material: Material
@export var core_shader: Shader
@export_group("Socket Feedback")
@export var socket_light_mesh: MeshInstance3D # Drag the end cap/light mesh here if this block has one

@onready var start_point: Marker3D = $StartPoint
@onready var end_point: Marker3D = $EndPoint
## Optional bend point if you want a 3-point curve shape.
@onready var bend_point: Node = get_node_or_null("BendPoint")

@onready var wire_glass_mesh: MeshInstance3D = $WireGlassMesh
@onready var wire_core_mesh: MeshInstance3D = $WireCoreMesh

var core_material: ShaderMaterial
var animation_tween: Tween
var is_lit: bool = false


func _ready() -> void:
	curve = curve.duplicate(true) if curve != null else Curve3D.new()
	_setup_curve()

	if core_shader != null:
		core_material = ShaderMaterial.new()
		core_material.shader = core_shader
		core_material.set_shader_parameter("progress", 1.0 if core_on_by_default else 0.0)
		# Draw the core before the transparent glass
		core_material.render_priority = -1

	_rebuild_mesh()

	if core_on_by_default:
		is_lit = true
		wire_core_mesh.visible = true
		if core_material != null:
			core_material.set_shader_parameter("progress", 1.0)
	else:
		is_lit = false
		wire_core_mesh.visible = false
		if core_material != null:
			core_material.set_shader_parameter("progress", 0.0)


func _setup_curve() -> void:
	curve.clear_points()
	if start_point != null and end_point != null:
		curve.add_point(start_point.position)
		if bend_point != null:
			curve.add_point(bend_point.position)
		curve.add_point(end_point.position)
	else:
		curve.add_point(Vector3.ZERO)
		curve.add_point(Vector3(1, 0, 0))

	_update_curve_shape()


func _update_curve_shape() -> void:
	if curve.point_count == 3:
		var start: Vector3 = curve.get_point_position(0)
		var bend: Vector3 = curve.get_point_position(1)
		var end: Vector3 = curve.get_point_position(2)

		var straight_direction: Vector3 = bend - start
		var flex_direction: Vector3 = end - bend
		var flex_length: float = flex_direction.length()

		if straight_direction.length_squared() >= 0.000001 and flex_length >= 0.001:
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
	elif curve.point_count == 2:
		var start: Vector3 = curve.get_point_position(0)
		var end: Vector3 = curve.get_point_position(1)
		var dir: Vector3 = end - start
		var length: float = dir.length()
		if length > 0.001:
			var handle := dir.normalized() * (length * 0.33) + sag_direction.normalized() * sag_amount
			curve.set_point_out(0, handle)
			curve.set_point_in(1, -handle)


## Lights up the wire core with the same tween animation as PuzzleWire.
func light_up() -> void:
	if is_lit:
		return
	is_lit = true

	if animation_tween and animation_tween.is_running():
		animation_tween.kill()

	wire_core_mesh.visible = true
	if core_material == null:
		return

	var current: float = float(core_material.get_shader_parameter("progress"))
	animation_tween = create_tween()
	animation_tween.tween_method(_set_wire_progress, current, 1.0, animation_duration)
	
	# Turn on the socket/cap light ONLY when the wire progress finishes filling
	animation_tween.tween_callback(func():
		if socket_light_mesh != null:
			socket_light_mesh.visible = true
	)


func turn_off() -> void:
	if not is_lit:
		return
	is_lit = false

	if animation_tween and animation_tween.is_running():
		animation_tween.kill()

	# Hide socket light immediately when turning off
	if socket_light_mesh != null:
		socket_light_mesh.visible = false

	if core_material == null:
		wire_core_mesh.visible = false
		return

	var current: float = float(core_material.get_shader_parameter("progress"))
	animation_tween = create_tween()
	animation_tween.tween_method(_set_wire_progress, current, 0.0, animation_duration * 0.5)
	animation_tween.tween_callback(func(): 
		wire_core_mesh.visible = false
	)

func _set_wire_progress(value: float) -> void:
	if core_material != null:
		core_material.set_shader_parameter("progress", value)


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
	var points := curve.get_baked_points()

	if points.size() < 2:
		wire_glass_mesh.mesh = null
		wire_core_mesh.mesh = null
		return

	wire_glass_mesh.mesh = _build_wire_mesh(points, glass_radius, glass_material)
	wire_core_mesh.mesh = _build_wire_mesh(points, core_radius, core_material)
