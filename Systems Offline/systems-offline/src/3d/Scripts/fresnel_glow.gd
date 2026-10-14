extends MeshInstance3D

@onready var mat_overlay: ShaderMaterial = material_overlay as ShaderMaterial

func set_interactable_glow(active: bool) -> void:
	if active:
		material_overlay = mat_overlay # Show shader overlay
	else:
		material_overlay = null # Hide shader overlay
