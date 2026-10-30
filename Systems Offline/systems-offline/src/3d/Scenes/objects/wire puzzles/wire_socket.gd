class_name WireSocket
extends Area3D

@export_category("Socket Settings")
@export var light_socket: MeshInstance3D
@export var socket_id: int = 0
@export var snap_distance: float = 0.3

@onready var snap_point: Marker3D = $SnapPoint

var occupied: bool = false


func _ready() -> void:
	if light_socket != null:
		light_socket.visible = false
	add_to_group("wire_sockets")


func get_snap_position() -> Vector3:
	return snap_point.global_position


func can_connect(wire_id: int) -> bool:
	return not occupied and wire_id == socket_id


func connect_wire() -> void:
	occupied = true


func disconnect_wire() -> void:
	occupied = false
	if light_socket != null:
		light_socket.visible = false
