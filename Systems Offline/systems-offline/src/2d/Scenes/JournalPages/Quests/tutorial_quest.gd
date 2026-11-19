extends Control



func animate_quest_writing(quest_label: Label) -> void:
	var shader_material := quest_label.material as ShaderMaterial

	if shader_material == null:
		return

	# Each objective needs its own material instance.
	shader_material = shader_material.duplicate() as ShaderMaterial
	quest_label.material = shader_material

	shader_material.set_shader_parameter("progress", 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)

	tween.tween_method(
		func(value: float) -> void:
			shader_material.set_shader_parameter("progress", value),
		0.0,
		1.0,
		1.0
	)
