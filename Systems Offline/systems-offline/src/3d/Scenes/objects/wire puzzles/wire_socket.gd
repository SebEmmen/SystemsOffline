class_name WireSocket
extends Area3D

@export_category("Socket Settings")
@export var light_socket: MeshInstance3D
@export var connector: MeshInstance3D
@export var connected_wire_segment: WirePuzzleStationary # <--- Drag your stationary wire here!
@export var socket_id: int = 0
@export var snap_distance: float = 0.3
@export var light_on: bool = false
@export var has_connector: bool = false

@onready var snap_point: Marker3D = get_node_or_null("SnapPoint")

var occupied: bool = false


func _ready() -> void:
	if light_socket != null && !light_on:
		light_socket.visible = false
	if connector != null && !has_connector:
		connector.visible = false
	
	# Match initial light state if core is on by default
	if core_on_by_default_check() and connected_wire_segment != null:
		connected_wire_segment.light_up()
		
	add_to_group("wire_sockets")


func core_on_by_default_check() -> bool:
	return connected_wire_segment != null and connected_wire_segment.core_on_by_default


func get_snap_position() -> Vector3:
	if snap_point != null:
		return snap_point.global_position
	return global_position


func can_connect(wire_id: int) -> bool:
	return not occupied and wire_id == socket_id


func connect_wire() -> void:
	occupied = true
	if connected_wire_segment != null:
		connected_wire_segment.light_up()


func disconnect_wire() -> void:
	occupied = false
	if light_socket != null:
		light_socket.visible = false
	if connected_wire_segment != null:
		connected_wire_segment.turn_off()
