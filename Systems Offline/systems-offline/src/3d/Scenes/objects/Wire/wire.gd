
@tool
extends Path3D

@export_category("Wire")
@export var wire_radius: float = 0.025:
	set(value):
		wire_radius = value
		update_wire()

@export_range(3, 16) var wire_sides: int = 8:
	set(value):
		wire_sides = value
		update_wire()

@export_category("Animation")
@export var animation_duration: float = 2.0
@export var wire_shader: Shader:
	set(value):
		wire_shader = value
		update_wire()

var wire_material: ShaderMaterial
var unlock_tween: Tween
var is_unlocked: bool = false

@onready var wire_mesh: MeshInstance3D = $WireMesh


func _ready() -> void:
	if curve != null:
		if not curve.changed.is_connected(update_wire):
			curve.changed.connect(update_wire)

	update_wire()


func update_wire() -> void:
	if not is_node_ready():
		return

	if curve == null or curve.point_count < 2:
		wire_mesh.mesh = null
		return

	var points := curve.get_baked_points()

	if points.size() < 2:
		wire_mesh.mesh = null
		return

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Calculate total wire length.
	var total_length := 0.0

	for i in range(1, points.size()):
		total_length += points[i - 1].distance_to(points[i])

	var current_length := 0.0

	# Generate the wire geometry.
	for i in range(points.size()):

		if i > 0:
			current_length += points[i - 1].distance_to(points[i])

		var direction: Vector3

		if i < points.size() - 1:
			direction = (
				points[i + 1] - points[i]
			).normalized()
		else:
			direction = (
				points[i] - points[i - 1]
			).normalized()

		var axis := direction.cross(Vector3.UP)

		if axis.length_squared() < 0.001:
			axis = direction.cross(Vector3.RIGHT)

		axis = axis.normalized()

		var second_axis := direction.cross(axis).normalized()

		# Generate circular vertices.
		for j in range(wire_sides):

			var angle := TAU * float(j) / float(wire_sides)

			var offset := (
				axis * cos(angle)
				+ second_axis * sin(angle)
			) * wire_radius

			# UV.y represents distance along the wire.
			surface.set_uv(Vector2(
				float(j) / float(wire_sides),
				current_length / maxf(total_length, 0.0001)
			))

			surface.add_vertex(points[i] + offset)

			# Connect adjacent rings.
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

	# Create a unique shader material for this wire.
	if wire_shader != null:

		if wire_material == null or wire_material.shader != wire_shader:
			wire_material = ShaderMaterial.new()
			wire_material.shader = wire_shader

			wire_material.set_shader_parameter(
				"progress",
				1.0 if is_unlocked else 0.0
			)

		surface.set_material(wire_material)

	wire_mesh.mesh = surface.commit()


# Animate green color from keypad to door.
func set_unlocked() -> void:
	if Engine.is_editor_hint():
		return

	if wire_material == null:
		return

	if unlock_tween and unlock_tween.is_running():
		unlock_tween.kill()

	var start_progress: float = wire_material.get_shader_parameter(
		"progress"
	)

	unlock_tween = create_tween()

	unlock_tween.tween_method(
		set_wire_progress,
		start_progress,
		1.0,
		animation_duration
	)

	unlock_tween.finished.connect(
		func(): is_unlocked = true
	)


# Update the shader's animation progress.
func set_wire_progress(value: float) -> void:
	if wire_material != null:
		wire_material.set_shader_parameter("progress", value)


# Reset wire to locked (red).
func set_locked() -> void:
	if unlock_tween and unlock_tween.is_running():
		unlock_tween.kill()

	is_unlocked = false
	set_wire_progress(0.0)
