
@tool
extends Path3D

var _last_curve: Curve3D
var _last_curve_state: PackedVector3Array = PackedVector3Array()


var previous_curve_state: PackedVector3Array


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	if not is_node_ready():
		return

	if not is_instance_valid(wire_mesh):
		return

	if curve == null:
		return

	var current_state := PackedVector3Array()

	for i in range(curve.point_count):
		current_state.append(curve.get_point_position(i))
		current_state.append(curve.get_point_in(i))
		current_state.append(curve.get_point_out(i))

	if current_state != previous_curve_state:
		previous_curve_state = current_state
		update_wire()


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
	if not curve_changed.is_connected(update_wire):
		curve_changed.connect(update_wire)

	# Enable live updates in the Godot editor.
	if Engine.is_editor_hint():
		set_process(true)

	update_wire()



func _get_curve_points() -> PackedVector3Array:
	var points := PackedVector3Array()

	if curve == null:
		return points

	for i in range(curve.point_count):
		points.append(curve.get_point_position(i))
		points.append(curve.get_point_in(i))
		points.append(curve.get_point_out(i))

	return points


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


	# Generate wire geometry with consistent thickness at bends.
	var previous_direction := Vector3.ZERO
	var ring_axis := Vector3.ZERO

	for i in range(points.size()):
		if i > 0:
			current_length += points[i - 1].distance_to(points[i])

		var incoming := Vector3.ZERO
		var outgoing := Vector3.ZERO

		if i > 0:
			incoming = (
				points[i] - points[i - 1]
			).normalized()

		if i < points.size() - 1:
			outgoing = (
				points[i + 1] - points[i]
			).normalized()

		# Average both directions at a corner.
		var direction: Vector3

		if i == 0:
			direction = outgoing
		elif i == points.size() - 1:
			direction = incoming
		else:
			direction = (incoming + outgoing).normalized()

			if direction.is_zero_approx():
				direction = outgoing

		if direction.is_zero_approx():
			continue

		# Keep the circular frame aligned between points.
		if i == 0:
			ring_axis = direction.cross(Vector3.UP)

			if ring_axis.length_squared() < 0.000001:
				ring_axis = direction.cross(Vector3.RIGHT)

			ring_axis = ring_axis.normalized()
		else:
			if previous_direction.dot(direction) > -0.999:
				var rotation := Quaternion(
					previous_direction,
					direction
				)
				ring_axis = rotation * ring_axis

			ring_axis = (
				ring_axis
				- direction * ring_axis.dot(direction)
			).normalized()

			if ring_axis.length_squared() < 0.000001:
				ring_axis = direction.cross(Vector3.UP)

				if ring_axis.length_squared() < 0.000001:
					ring_axis = direction.cross(Vector3.RIGHT)

				ring_axis = ring_axis.normalized()

		var second_axis := direction.cross(ring_axis).normalized()

		previous_direction = direction

		# Miter correction prevents thinning at corners.
		var miter_factor := 1.0
		var bend_direction := Vector3.ZERO

		if i > 0 and i < points.size() - 1:
			var turn_dot := clampf(
				incoming.dot(outgoing),
				-1.0,
				1.0
			)

			if turn_dot < 0.999:
				bend_direction = (
					outgoing - incoming
				).normalized()

				miter_factor = minf(
					2.0,
					sqrt(
						2.0 / maxf(1.0 + turn_dot, 0.01)
					)
				)

		# Generate circular vertices.
		for j in range(wire_sides):
			var angle := TAU * float(j) / float(wire_sides)

			var offset := (
				ring_axis * cos(angle)
				+ second_axis * sin(angle)
			) * wire_radius

			# Correct the ring shape at sharp turns.
			if not bend_direction.is_zero_approx():
				var bend_component := offset.dot(bend_direction)

				offset += (
					bend_direction
					* bend_component
					* (miter_factor - 1.0)
				)

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
func set_unlocked(instant: bool = false) -> void:
	if Engine.is_editor_hint():
		return

	# Remember the state, so update_wire() builds the material already green
	# if the wire wasn't ready yet.
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
	

# Check for changes to the wire curve in the editor.


# Read all curve points and their handles.
func _get_curve_state() -> PackedVector3Array:
	var state := PackedVector3Array()

	if curve == null:
		return state

	for i in range(curve.point_count):
		state.append(curve.get_point_position(i))
		state.append(curve.get_point_in(i))
		state.append(curve.get_point_out(i))

	return state
