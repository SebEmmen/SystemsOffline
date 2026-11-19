class_name Piece
extends Area2D

static var locked := false   # set by the puzzle while grids are rotating

@export var snap_radius := 70.0

var slot: Slot = null
var dragging := false
var drag_offset := Vector2.ZERO
var last_slot: Slot = null
var start_slot: Slot = null
var start_rotation := 0.0

func _ready() -> void:
	add_to_group("pieces")
	input_pickable = true
	input_event.connect(_on_input_event)
	_claim_start_slot.call_deferred()

func _claim_start_slot() -> void:
	if get_parent() is Slot:
		_place(get_parent(), false)
	else:
		var s := _nearest_free_slot()
		if s:
			_place(s, false)
	# remember where we began so the board can be reset
	start_slot = slot
	start_rotation = rotation

func release() -> void:
	dragging = false
	z_index = 0
	z_as_relative = true
	if slot:
		slot.piece = null
		slot = null

func return_to_start(duration: float) -> void:
	if start_slot == null:
		return
	slot = start_slot
	start_slot.piece = self
	reparent(start_slot, true)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", Vector2.ZERO, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var from := rotation
	tw.tween_method(func(t: float): rotation = lerp_angle(from, start_rotation, t),
		0.0, 1.0, duration)

func _on_input_event(_vp: Node, event: InputEvent, _idx: int) -> void:
	if locked or dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		drag_offset = global_position - get_global_mouse_position()
		last_slot = slot
		if slot:
			slot.piece = null
			slot = null
		z_as_relative = false
		z_index = 100

func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		z_index = 0
		z_as_relative = true
		var target := _nearest_free_slot()
		if target == null:
			target = last_slot   # nothing nearby, go back where we came from
		if target:
			_place(target, true)

func _nearest_free_slot() -> Slot:
	var best: Slot = null
	var best_dist := snap_radius
	for s: Slot in get_tree().get_nodes_in_group("slots"):
		if not s.is_free():
			continue
		var d := global_position.distance_to(s.global_position)
		if d < best_dist:
			best_dist = d
			best = s
	return best

func _place(s: Slot, animate: bool) -> void:
	slot = s
	s.piece = self
	reparent(s, true)   # true = keep global transform, so no visual jump
	if animate:
		var tw := create_tween()
		tw.tween_property(self, "position", Vector2.ZERO, 0.1)
	else:
		position = Vector2.ZERO
