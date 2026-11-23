class_name Piece3D
extends Area3D

static var locked := false
signal placed

@export var kind := "corner"          # set per piece scene: "straight", "t", "corner"
@export var symmetry_deg := 360.0     # 180 for straight pieces, 360 for T and corner

@export var snap_radius := 0.7        # world units now, not pixels
@export var lift_height := 0.3        # how far the piece rises while held
@export var anchor: Node3D   # optional; falls back to a child named "Anchor"



# Rotation around Y in world space, folded by the piece's symmetry
func board_angle() -> float:
	var x := global_basis.x
	return fposmod(rad_to_deg(atan2(-x.z, x.x)), symmetry_deg)

@export var free_parent: Node3D      # where loose pieces live; defaults to the starting parent
@export var play_min := Vector2(-8, -6)   # optional X/Z limits for loose pieces
@export var play_max := Vector2(8, 6)

var home_parent: Node
var start_global_pos := Vector3.ZERO
var start_global_rot_y := 0.0
var rest_y := 0.0
var start_basis := Basis.IDENTITY
var slot: Slot3D = null
var dragging := false
var drag_offset := Vector3.ZERO
var drag_plane_y := 0.0
var last_slot: Slot3D = null
var start_slot: Slot3D = null
var start_rotation_y := 0.0

func _ready() -> void:
	add_to_group("pieces")
	if anchor == null:
		anchor = get_node_or_null("Anchor")
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	if free_parent:
		home_parent = free_parent
	elif not get_parent() is Slot3D:
		home_parent = get_parent()
	else:
		home_parent = get_tree().current_scene
	start_global_pos = global_position
	start_global_rot_y = global_rotation.y
	rest_y = global_position.y
	_claim_start_slot.call_deferred()


func _claim_start_slot() -> void:
	if get_parent() is Slot3D:
		_place(get_parent(), false)
	else:
		var s := _nearest_free_slot()
		if s:
			_place(s, false)
	start_slot = slot
	start_rotation_y = rotation.y
	start_basis = basis

func release() -> void:
	dragging = false
	if slot:
		slot.piece = null
		slot = null

func return_to_start(duration: float) -> void:
	if start_slot == null:
		slot = null
		if get_parent() != home_parent:
			reparent(home_parent, true)
		var tw0 := create_tween().set_parallel(true)
		tw0.tween_property(self, "global_position", start_global_pos, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var from0 := global_rotation.y
		tw0.tween_method(func(t: float): global_rotation.y = lerp_angle(from0, start_global_rot_y, t),
			0.0, 1.0, duration)
		return
	slot = start_slot
	start_slot.piece = self
	reparent(start_slot, true)
	var target := Vector3.ZERO
	if anchor:
		target = -(start_basis * anchor.position)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var from := rotation.y
	tw.tween_method(func(t: float): rotation.y = lerp_angle(from, start_rotation_y, t),
		0.0, 1.0, duration)

# Note the different signature compared to Area2D
func _on_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if locked or dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		drag_plane_y = global_position.y + lift_height
		var hit = _mouse_on_plane()
		drag_offset = global_position - hit if hit else Vector3.ZERO
		drag_offset.y = 0.0
		last_slot = slot
		if slot:
			slot.piece = null
			slot = null

func _mouse_on_plane():
	var cam := get_viewport().get_camera_3d()
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	return Plane(Vector3.UP, drag_plane_y).intersects_ray(from, dir)  # null if no hit

func _process(_delta: float) -> void:
	if dragging:
		var hit = _mouse_on_plane()
		if hit:
			global_position = hit + drag_offset
			global_position.y = drag_plane_y

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		var target := _nearest_free_slot()
		if target:
			_place(target, true)
		else:
			_drop_free()

func _drop_free() -> void:
	slot = null
	if get_parent() != home_parent:
		reparent(home_parent, true)   # leave the grid so it stops rotating with it
	var end_pos := Vector3(
		clampf(global_position.x, play_min.x, play_max.x),
		rest_y,
		clampf(global_position.z, play_min.y, play_max.y))
	var from := global_rotation.y
	var to := snappedf(from, PI / 2.0)   # tidy up to a 90 degree angle
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", end_pos, 0.1)
	tw.tween_method(func(t: float): global_rotation.y = lerp_angle(from, to, t),
		0.0, 1.0, 0.1)

func _nearest_free_slot() -> Slot3D:
	var best: Slot3D = null
	var best_dist := snap_radius
	var c := _center()
	var my_pos := Vector2(c.x, c.z)
	for s: Slot3D in get_tree().get_nodes_in_group("slots"):
		if not s.is_free():
			continue
		var d := my_pos.distance_to(Vector2(s.global_position.x, s.global_position.z))
		if d < best_dist:
			best_dist = d
			best = s
	return best

func _center() -> Vector3:
	return anchor.global_position if anchor else global_position

# Local position that puts the anchor exactly on the slot origin
# (the piece's local basis is what rotates the offset)
func _local_pos_for_anchor() -> Vector3:
	if anchor == null:
		return Vector3.ZERO
	return -(basis * anchor.position)

func _place(s: Slot3D, animate: bool) -> void:
	slot = s
	s.piece = self
	reparent(s, true)
	# snap rotation to the nearest 90 degrees in the slot's frame
	var target_rot := snappedf(rotation.y, PI / 2.0)
	var target_basis := Basis(Vector3.UP, target_rot)
	var target := Vector3.ZERO
	if anchor:
		target = -(target_basis * anchor.position)
	if animate:
		var from := rotation.y
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "position", target, 0.1)
		tw.tween_method(func(t: float): rotation.y = lerp_angle(from, target_rot, t),
			0.0, 1.0, 0.1)
	else:
		rotation.y = target_rot
		position = target
