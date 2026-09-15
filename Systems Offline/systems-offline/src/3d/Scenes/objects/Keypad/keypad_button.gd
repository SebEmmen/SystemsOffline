extends StaticBody3D

@export var key_value: String
@export var button_mesh: MeshInstance3D
@export var hover_material: Material


func interact() -> void:
	var keypad = get_parent()

	# Buttons only work while we're in keypad view mode
	if not keypad.using_keypad:
		return

	print("Hit node: ", name, " | key value: ", key_value)
	keypad.press_key(key_value)


func set_hovered(hovered: bool) -> void:
	if hovered:
		button_mesh.material_overlay = hover_material
	else:
		button_mesh.material_overlay = null
