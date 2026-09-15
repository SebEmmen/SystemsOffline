extends RayCast3D

@onready var interaction_label: Label = get_tree().current_scene.get_node("HUD/InteractionLabel")
@onready var player: CharacterBody3D = owner


func _process(_delta: float) -> void:
	if not player.controls_enabled:
		interaction_label.visible = false
		return

	if is_colliding():
		var hit_obj = get_collider()

		if hit_obj.has_method("interact"):
			interaction_label.visible = true

			if Input.is_action_just_pressed("interact"):
				hit_obj.interact()
		else:
			interaction_label.visible = false
	else:
		interaction_label.visible = false
