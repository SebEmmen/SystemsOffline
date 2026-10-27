
class_name BookController
extends Node3D

@export var spreads: Array[BookSpreadData] = []
@export var fade_duration: float = 0.2

@onready var left_viewport: SubViewport = $LeftPageViewport
@onready var right_viewport: SubViewport = $RightPageViewport
@onready var visual_root: Node3D = $VisualRoot

var current_spread: int = 0
var is_turning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	print("BOOK READY")
	print("Spread count: ", spreads.size())

	# Do not load any pages yet.

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			print("Loading first spread")
			load_spread(0)

func load_spread(index: int) -> void:
	if index < 0 or index >= spreads.size():
		return

	current_spread = index
	var spread: BookSpreadData = spreads[index]

	_load_page(left_viewport, spread.left_page)
	_load_page(right_viewport, spread.right_page)


func _load_page(viewport: SubViewport, page_scene: PackedScene) -> void:
	# Remove existing page content
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()	
	if page_scene == null:
		return	
	var page := page_scene.instantiate() as Control	
	if page == null:
		push_error("Book page scene must have a Control root.")
		return	
	viewport.add_child(page)	
	page.position = Vector2.ZERO
	page.size = Vector2(viewport.size)
	page.process_mode = Node.PROCESS_MODE_ALWAYS


func change_spread(index: int) -> void:
	if is_turning or index < 0 or index >= spreads.size():
		return

	if index == current_spread:
		return

	is_turning = true

	var left_page: Control = left_viewport.get_child(0) as Control
	var right_page: Control = right_viewport.get_child(0) as Control

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)

	if left_page:
		tween.tween_property(left_page, "modulate:a", 0.0, fade_duration)
	if right_page:
		tween.tween_property(right_page, "modulate:a", 0.0, fade_duration)

	await tween.finished

	load_spread(index)

	left_page = left_viewport.get_child(0) as Control if left_viewport.get_child_count() > 0 else null
	right_page = right_viewport.get_child(0) as Control if right_viewport.get_child_count() > 0 else null

	if left_page:
		left_page.modulate.a = 0.0
	if right_page:
		right_page.modulate.a = 0.0

	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)

	if left_page:
		tween.tween_property(left_page, "modulate:a", 1.0, fade_duration)
	if right_page:
		tween.tween_property(right_page, "modulate:a", 1.0, fade_duration)

	await tween.finished

	is_turning = false


func next_spread() -> void:
	change_spread(current_spread + 1)


func previous_spread() -> void:
	change_spread(current_spread - 1)
