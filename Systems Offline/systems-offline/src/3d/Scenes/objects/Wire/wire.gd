
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

var wire_mesh: MeshInstance3D
var connected_curve: Curve3D


func _ready() -> void:
	wire_mesh = get_node_or_null("WireMesh")

	connect_curve()
	set_process(true)
	update_wire()


func _process(_delta: float) -> void:
	# Detect when Make Unique replaces the Curve3D resource.
	if curve != connected_curve:
		connect_curve()
		update_wire()


func _exit_tree() -> void:
	if connected_curve != null:
		if connected_curve.changed.is_connected(update_wire):
			connected_curve.changed.disconnect(update_wire)

	connected_curve = null


func connect_curve() -> void:
	# Disconnect the previous curve.
	if connected_curve != null:
		if connected_curve.changed.is_connected(update_wire):
			connected_curve.changed.disconnect(update_wire)

	# Connect the new curve.
	connected_curve = curve

	if connected_curve != null:
		if not connected_curve.changed.is_connected(update_wire):
			connected_curve.changed.connect(update_wire)


func update_wire() -> void:
	if not is_inside_tree():
		return

	# Retrieve the child safely, including in the editor.
	wire_mesh = get_node_or_null("WireMesh")

	if wire_mesh == null:
		return

	# Always clear the previous generated geometry.
	wire_mesh.mesh = null

	# A wire requires at least two curve points.
	if curve == null or curve.point_count < 2:
		return

	var baked_points: PackedVector3Array = curve.get_baked_points()

	if baked_points.size() < 2:
		return

	# Remove duplicate consecutive points.
	var points: Array[Vector3] = []

	for point in baked_points:
		if points.is_empty():
			points.append(point)
		elif points.back().distance_squared_to(point) > 0.000001:
			points.append(point)

	if points.size() < 2:
		return

	# Calculate total length.
	var total_length: float = 0.0

	for i in range(1, points.size()):
		total_length += points[i - 1].distance_to(points[i])

	if total_length < 0.0001:
		return

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var current_length: float = 0.0

	# Maintain a consistent orientation along the wire.
	var previous_axis: Vector3 = Vector3.ZERO

	for i in range(points.size()):
		if i > 0:
			current_length += points[i - 1].distance_to(points[i])

		# Calculate the direction along the curve.
		var direction: Vector3

		if i < points.size() - 1:
			direction = points[i + 1] - points[i]
		else:
			direction = points[i] - points[i - 1]

		if direction.length_squared() < 0.000001:
			continue

		direction = direction.normalized()

		var axis: Vector3

		if i == 0:
			# Choose a reference axis perpendicular to the wire.
			axis = direction.cross(Vector3.UP)

			if axis.length_squared() < 0.0001:
				axis = direction.cross(Vector3.RIGHT)

			axis = axis.normalized()
		else:
			# Keep the orientation consistent between rings.
			axis = previous_axis - direction * previous_axis.dot(direction)

			if axis.length_squared() < 0.0001:
				axis = direction.cross(Vector3.UP)

				if axis.length_squared() < 0.0001:
					axis = direction.cross(Vector3.RIGHT)

			axis = axis.normalized()

		var second_axis: Vector3 = direction.cross(axis).normalized()

		previous_axis = axis

		# Generate circular vertices.
		for j in range(wire_sides):
			var angle: float = TAU * float(j) / float(wire_sides)

			var offset: Vector3 = (
				axis * cos(angle)
				+ second_axis * sin(angle)
			) * wire_radius

			# UV.y represents progress along the wire.
			surface.set_uv(Vector2(
				float(j) / float(wire_sides),
				current_length / total_length
			))

			surface.add_vertex(points[i] + offset)

			# Connect adjacent rings.
			if i > 0:
				var previous: int = (i - 1) * wire_sides
				var current: int = i * wire_sides
				var next_j: int = (j + 1) % wire_sides

				surface.add_index(previous + j)
				surface.add_index(previous + next_j)
				surface.add_index(current + j)

				surface.add_index(current + j)
				surface.add_index(previous + next_j)
				surface.add_index(current + next_j)

	surface.generate_normals()

	# Give each wire its own shader material.
	if wire_shader != null:
		if wire_material == null or wire_material.shader != wire_shader:
			wire_material = ShaderMaterial.new()
			wire_material.shader = wire_shader

			wire_material.set_shader_parameter(
				"progress",
				1.0 if is_unlocked else 0.0
			)

		surface.set_material(wire_material)

	# Assign the generated mesh.
	wire_mesh.mesh = surface.commit()


# Animate green color from keypad to door.
func set_unlocked(instant: bool = false) -> void:
	if Engine.is_editor_hint():
		return

	is_unlocked = true

	if wire_material == null:
		return

	if unlock_tween and unlock_tween.is_running():
		unlock_tween.kill()

	if instant:
		set_wire_progress(1.0)
		return

	var start_progress: float = wire_material.get_shader_parameter("progress")

	unlock_tween = create_tween()
	unlock_tween.tween_method(
		set_wire_progress,
		start_progress,
		1.0,
		animation_duration
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
