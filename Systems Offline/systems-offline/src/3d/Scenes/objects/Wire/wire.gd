
@tool
extends Path3D

var connected_curve: Curve3D

@export_category("Wire")
@export var wire_radius: float = 0.025:
	set(value):
		wire_radius = value
		update_wire()

@export_range(3, 16) var wire_sides: int = 8:
	set(value):
		wire_sides = value
		update_wire()

@export_range(0.01, 1.0, 0.01)
var minimum_bend_radius: float = 0.1:
	set(value):
		minimum_bend_radius = value
		update_wire()

@export_range(2, 16) var corner_segments: int = 6:
	set(value):
		corner_segments = value
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
	connect_curve()
	update_wire()


func update_wire() -> void:
	if not is_node_ready():
		return

	if curve == null or curve.point_count < 2:
		wire_mesh.mesh = null
		return

	var baked_points := curve.get_baked_points()

	if baked_points.size() < 2:
		wire_mesh.mesh = null
		return

	# Round corners without modifying the original curve.
	var points := get_smoothed_wire_points(baked_points)

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

	# Parallel transport frame.
	var previous_direction := Vector3.ZERO
	var axis := Vector3.ZERO
	var second_axis := Vector3.ZERO

	for i in range(points.size()):

		if i > 0:
			current_length += points[i - 1].distance_to(points[i])

		# Calculate the tangent.
		var direction: Vector3

		if i == 0:
			direction = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			direction = (points[i] - points[i - 1]).normalized()
		else:
			direction = (
				points[i + 1] - points[i - 1]
			).normalized()

		# Calculate ring orientation.
		if i == 0:
			var reference := Vector3.UP

			if absf(direction.dot(reference)) > 0.9:
				reference = Vector3.RIGHT

			axis = direction.cross(reference).normalized()
			second_axis = direction.cross(axis).normalized()

		else:
			var rotation_axis := previous_direction.cross(direction)
			var rotation_length := rotation_axis.length()

			if rotation_length > 0.00001:
				rotation_axis /= rotation_length

				var rotation_angle := atan2(
					rotation_length,
					previous_direction.dot(direction)
				)

				var rotation := Basis(
					rotation_axis,
					rotation_angle
				)

				axis = rotation * axis

			axis = (
				axis - direction * axis.dot(direction)
			).normalized()

			second_axis = direction.cross(axis).normalized()

		previous_direction = direction

		# Generate circular vertices.
		for j in range(wire_sides):
			var angle := TAU * float(j) / float(wire_sides)

			var offset := (
				axis * cos(angle)
				+ second_axis * sin(angle)
			) * wire_radius

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

	# Create a unique shader material.
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


# Round sharp corners with circular arcs.
# The original Curve3D remains unchanged.
func get_smoothed_wire_points(
	source_points: PackedVector3Array
) -> PackedVector3Array:

	var result := PackedVector3Array()

	if source_points.size() < 3:
		return source_points

	result.append(source_points[0])

	var count := source_points.size()

	for i in range(1, count - 1):

		var previous := source_points[i - 1]
		var current := source_points[i]
		var following := source_points[i + 1]

		var incoming := current - previous
		var outgoing := following - current

		var incoming_length := incoming.length()
		var outgoing_length := outgoing.length()

		if incoming_length < 0.0001 or outgoing_length < 0.0001:
			continue

		var dir_in := incoming / incoming_length
		var dir_out := outgoing / outgoing_length

		var angle := dir_in.angle_to(dir_out)

		# Almost straight: preserve the point.
		if angle < 0.01:
			result.append(current)
			continue

		# Near U-turns cannot be rounded reliably.
		if angle > PI - 0.01:
			result.append(current)
			continue

		var tangent_distance := (
			minimum_bend_radius * tan(angle * 0.5)
		)

		# Prevent the arc from extending beyond the
		# neighboring points.
		var available_distance := minf(
			incoming_length,
			outgoing_length
		) * 0.45

		tangent_distance = minf(
			tangent_distance,
			available_distance
		)

		if tangent_distance < 0.0001:
			result.append(current)
			continue

		var actual_radius := (
			tangent_distance / tan(angle * 0.5)
		)

		var arc_start := current - dir_in * tangent_distance
		var arc_end := current + dir_out * tangent_distance

		var normal := dir_in.cross(dir_out).normalized()

		if normal.length_squared() < 0.0001:
			result.append(current)
			continue

		# Find the circle center.
		var center_direction := normal.cross(dir_in)
		var center := arc_start + center_direction * actual_radius

		var radius_vector := arc_start - center

		# Generate points along the circular arc.
		for step in range(corner_segments + 1):
			var t := float(step) / float(corner_segments)

			var rotation := Basis(normal, angle * t)

			var point := center + rotation * radius_vector

			result.append(point)

	result.append(source_points[count - 1])

	return result


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


# Update shader progress.
func set_wire_progress(value: float) -> void:
	if wire_material != null:
		wire_material.set_shader_parameter("progress", value)


# Reset wire to locked (red).
func set_locked() -> void:
	if unlock_tween and unlock_tween.is_running():
		unlock_tween.kill()

	is_unlocked = false
	set_wire_progress(0.0)


# Connect curve changes to mesh updates.
func connect_curve() -> void:
	if connected_curve == curve:
		return

	if connected_curve != null:
		if connected_curve.changed.is_connected(update_wire):
			connected_curve.changed.disconnect(update_wire)

	connected_curve = curve

	if connected_curve != null:
		if not connected_curve.changed.is_connected(update_wire):
			connected_curve.changed.connect(update_wire)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		connect_curve()
