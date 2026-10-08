
@tool
extends Path3D

@export_category("Wire")
@export var wire_radius: float = 0.025:
	set(value):
		wire_radius = value
		update_wire()

@export var wire_color: Color = Color.DARK_RED:
	set(value):
		wire_color = value
		update_wire()

@export_range(3, 16) var wire_sides: int = 8:
	set(value):
		wire_sides = value
		update_wire()

@export_category("Animation")
@export var animation_duration: float = 2.0
@export var wire_shader: Shader

var wire_material: ShaderMaterial
var unlock_tween: Tween


@onready var wire_mesh: MeshInstance3D = $WireMesh



func _ready() -> void:
	if curve != null:
		curve.changed.connect(update_wire)

	update_wire()



func update_wire() -> void:
	if not is_node_ready():
		return

	if curve == null or curve.point_count < 2:
		return

	var tube := TubeTrailMesh.new()
	tube.radius = wire_radius
	tube.radial_steps = wire_sides

	# Generate a tube along the baked curve.
	var points := curve.get_baked_points()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size()):
		var direction: Vector3

		if i < points.size() - 1:
			direction = (points[i + 1] - points[i]).normalized()
		else:
			direction = (points[i] - points[i - 1]).normalized()

		var axis := direction.cross(Vector3.UP).normalized()
		if axis.length_squared() < 0.001:
			axis = direction.cross(Vector3.RIGHT).normalized()

		var second_axis := direction.cross(axis).normalized()

		for j in range(wire_sides):
			var angle := TAU * j / wire_sides
			var offset := (
				axis * cos(angle)
				+ second_axis * sin(angle)
			) * wire_radius

			surface.set_uv(Vector2(
				float(j) / float(wire_sides),
				float(i) / float(points.size() - 1)
			))
			surface.add_vertex(points[i] + offset)

			if i > 0:
				var previous := (i - 1) * wire_sides
				var current := i * wire_sides
				var next_j := (j + 1) % wire_sides

				surface.add_index(previous + j)
				surface.add_index(previous + next_j)
				surface.add_index(current + j)

				surface.add_index(current + j)
				surface.add_index(previous + next_j)
				surface.add_index(current + next_j)

	surface.generate_normals()


	if wire_shader != null:
		wire_material = ShaderMaterial.new()
		wire_material.shader = wire_shader
		wire_material.set_shader_parameter("progress", 0.0)

		surface.set_material(wire_material)

	wire_mesh.mesh = surface.commit()

	


func set_unlocked() -> void:
	if wire_material == null:
		return

	if unlock_tween:
		unlock_tween.kill()

	unlock_tween = create_tween()

	unlock_tween.tween_method(
		set_wire_progress,
		0.0,
		1,
		animation_duration
	)


func set_wire_progress(value: float) -> void:
	wire_material.set_shader_parameter("progress", value)
