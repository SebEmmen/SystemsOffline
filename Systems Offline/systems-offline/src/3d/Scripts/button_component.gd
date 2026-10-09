extends InteractableComponent

enum ButtonType{
	KEYPAD_BUTTON,
	BUTTON
}

@export var button_type: ButtonType

@export_group("Keypad Button")
@export var key_value: String
@export var button_mesh: MeshInstance3D
@export var hover_material: Material

func _ready() -> void:
	interaction_type = InteractionType.BUTTON

func interact() -> void:
	match button_type:
		ButtonType.KEYPAD_BUTTON:
			keypad_button_interact()
		ButtonType.BUTTON:
			button_interact()

#region Button Functions
func button_interact() -> void:
	pass
#endregion

#region Keypad Button Functions
func keypad_button_interact() -> void:
	var keypad = get_parent().get_parent().get_parent()

	if not keypad.is_interacting:
		return

	print("Hit node: ", name, " | key value: ", key_value)
	keypad.press_key(key_value)

func set_hovered(hovered: bool) -> void:
	if hovered:
		button_mesh.material_overlay = hover_material
	else:
		button_mesh.material_overlay = null
#endregion
