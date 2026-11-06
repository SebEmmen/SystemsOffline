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

#region Sound Effects Variables
@export_group("Sound Effects")
var primary_audio_player: AudioStreamPlayer3D
var secondary_audio_player: AudioStreamPlayer3D
var tertiary_audio_player: AudioStreamPlayer3D

@export var primary_se: AudioStream
@export var secondary_se: AudioStream
@export var tertiary_se: AudioStream
#endregion

@onready var snap_point: Marker3D = get_node_or_null("SnapPoint")

var occupied: bool = false


func _ready() -> void:
	_setup_audio_players()
	
	if light_socket != null && !light_on:
		light_socket.visible = false
	if connector != null && !has_connector:
		connector.visible = false
	
	# Match initial light state if core is on by default
	if core_on_by_default_check() and connected_wire_segment != null:
		connected_wire_segment.light_up()
		
	add_to_group("wire_sockets")


# Dynamically instantiates AudioStreamPlayer3D nodes for assigned streams
func _setup_audio_players() -> void:
	if primary_se:
		primary_audio_player = AudioStreamPlayer3D.new()
		primary_audio_player.stream = primary_se
		add_child(primary_audio_player)

	if secondary_se:
		secondary_audio_player = AudioStreamPlayer3D.new()
		secondary_audio_player.stream = secondary_se
		add_child(secondary_audio_player)

	if tertiary_se:
		tertiary_audio_player = AudioStreamPlayer3D.new()
		tertiary_audio_player.stream = tertiary_se
		add_child(tertiary_audio_player)

#region Audio Helper Functions
func play_primary_se() -> void:
	if primary_audio_player:
		primary_audio_player.play()

func play_secondary_se() -> void:
	if secondary_audio_player:
		secondary_audio_player.play()

func play_tertiary_se() -> void:
	if tertiary_audio_player:
		tertiary_audio_player.play()
#endregion


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
