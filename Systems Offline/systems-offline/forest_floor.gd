@tool
extends Node3D

@export var tile_scene: PackedScene:
	set(value):
		tile_scene = value
		_queue_rebuild()
		
@export var second_tile_scene: PackedScene:
	set(value):
		second_tile_scene = value
		_queue_rebuild()

@export var tile_size := Vector2(12.0, 12.0):
	set(value):
		tile_size = value
		_queue_rebuild()

@export_range(1, 50) var columns := 9:
	set(value):
		columns = value
		_queue_rebuild()

@export_range(1, 50) var rows := 9:
	set(value):
		rows = value
		_queue_rebuild()
		
@export var fern_clearing: Node3D:
	set(value):
		fern_clearing = value
		_queue_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return

	_rebuild_queued = true
	_rebuild_grid.call_deferred()


func _rebuild_grid() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return

	var previous_grid := get_node_or_null("_GeneratedForestTiles")
	if previous_grid != null:
		remove_child(previous_grid)
		previous_grid.queue_free()

	if tile_scene == null:
		return

	var grid := Node3D.new()
	grid.name = "_GeneratedForestTiles"
	add_child(grid)

	var clearing_outline := _get_clearing_outline()
	var rotation_rng := RandomNumberGenerator.new()
	rotation_rng.seed = 42
	var prop_rng := RandomNumberGenerator.new()
	var variant_rng := RandomNumberGenerator.new()
	var log_rng := RandomNumberGenerator.new()

	var angles := [0.0, 90.0, -90.0, 180.0]
	var center_offset := Vector2(columns - 1, rows - 1) * tile_size * 0.5

	for row in range(rows):
		for column in range(columns):
			var scene_to_use := tile_scene
			variant_rng.seed = hash(Vector3i(column, row, 44))
			if second_tile_scene != null and variant_rng.randf() < 0.5:
				scene_to_use = second_tile_scene

			var instance := scene_to_use.instantiate()
			var tile := instance as Node3D
			if tile == null:
				instance.free()
				push_error("Both tile scenes must have a Node3D root.")
				return

			var angle: float = angles[rotation_rng.randi_range(0, angles.size() - 1)]
			tile.rotation_degrees.y += angle
			tile.position += Vector3(
				column * tile_size.x - center_offset.x,
				0.0,
				row * tile_size.y - center_offset.y
			)
			grid.add_child(tile)

			prop_rng.seed = hash(Vector3i(column, row, 43))
			var show_log := prop_rng.randf() < 0.20
			var show_ferns := prop_rng.randf() < 0.65
			var show_stones := prop_rng.randf() < 0.45

			log_rng.seed = hash(Vector3i(column, row, 45))
			for node in tile.find_children("Fallen log*", "MeshInstance3D", true, false):
				var fallen_log := node as MeshInstance3D
				if show_log:
					fallen_log.rotation_degrees.y += log_rng.randf_range(0.0, 360.0)
					fallen_log.scale *= log_rng.randf_range(0.8, 1.2)
				else:
					fallen_log.free()

			var fern_scale := prop_rng.randf_range(0.85, 1.15) if (
				show_ferns and tile.find_child("Ferns", true, false) != null
			) else 1.0

			for node in tile.find_children("Fern*", "MeshInstance3D", true, false):
				var fern := node as MeshInstance3D
				var center := fern.to_global(fern.get_aabb().get_center())
				var in_clearing := clearing_outline.size() >= 3 and Geometry2D.is_point_in_polygon(
					Vector2(center.x, center.z), clearing_outline
				)

				if show_ferns and not in_clearing:
					fern.scale *= fern_scale
				else:
					fern.free()

			var stones := tile.find_child("Half-buried stones", true, false) as Node3D
			if stones != null:
				if show_stones:
					stones.scale *= prop_rng.randf_range(0.90, 1.10)
				else:
					stones.free()


func _get_clearing_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	if not is_instance_valid(fern_clearing):
		return outline

	for child in fern_clearing.get_children():
		var marker := child as Marker3D
		if marker == null:
			continue

		var point: Vector3 = marker.global_position
		outline.append(Vector2(point.x, point.z))

	return outline
