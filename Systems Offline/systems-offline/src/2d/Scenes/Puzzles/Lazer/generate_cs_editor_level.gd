@tool
extends EditorScript
## Run while an empty scene with Node2D root named CrossedSignalsLevel is open.
## Adds sample editable nodes; move, duplicate and resize them in the 2D editor.

const LEVEL_SCRIPT = preload("res://src/2d/Scenes/Puzzles/Lazer/cs_level.gd")
const DEVICE_SCRIPT = preload("res://src/2d/Scenes/Puzzles/Lazer/cs_device.gd")
const WALL_SCRIPT = preload("res://src/2d/Scenes/Puzzles/Lazer/cs_wall.gd")
const BARRIER_SCRIPT = preload("res://src/2d/Scenes/Puzzles/Lazer/cs_barrier.gd")

func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or not root is Node2D:
		push_error("Open a scene with a Node2D root first.")
		return
	if root.get_child_count() > 0:
		push_error("Root must have no children. This prevents overwriting your level.")
		return
	root.set_script(LEVEL_SCRIPT)
	_add_device(root, "RedEmitter", Vector2(80, 120), 0, 0)
	_add_device(root, "BlueEmitter", Vector2(80, 480), 0, 1)
	_add_device(root, "RedReceiver", Vector2(850, 120), 1, 0)
	_add_device(root, "BlueReceiver", Vector2(850, 480), 1, 1)
	for i in range(4):
		_add_device(root, "Relay%d" % (i + 1), Vector2(300 + i * 95, 300), 2, 0)
	_add_wall(root, "Wall1", Vector2(480, 150), Vector2(24, 220))
	_add_wall(root, "Wall2", Vector2(480, 460), Vector2(24, 220))
	var barrier: CSBarrier = BARRIER_SCRIPT.new()
	barrier.name = "BarrierA"
	barrier.position = Vector2(710, 300)
	root.add_child(barrier)
	barrier.owner = root
	barrier.dimensions = Vector2(20, 120)
	barrier.receiver_path = NodePath("../RedReceiver")
	EditorInterface.mark_scene_as_unsaved()
	print("Crossed Signals editor level created. Save the scene.")

func _add_device(root: Node2D, label: String, at: Vector2, kind: int, color: int) -> void:
	var node: CSDevice = DEVICE_SCRIPT.new()
	node.name = label
	node.position = at
	root.add_child(node)
	node.owner = root
	node.kind = kind
	node.laser_color = color
	node.device_label = label

func _add_wall(root: Node2D, label: String, at: Vector2, dimensions: Vector2) -> void:
	var node: CSWall = WALL_SCRIPT.new()
	node.name = label
	node.position = at
	root.add_child(node)
	node.owner = root
	node.dimensions = dimensions
