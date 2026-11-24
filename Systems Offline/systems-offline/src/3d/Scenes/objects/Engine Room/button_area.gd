extends Area3D
signal pressed

var disabled := false:
	set(v):
		disabled = v
		input_ray_pickable = not v

func _ready() -> void:
	input_ray_pickable = true
	input_event.connect(_on_input_event)

func _on_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
