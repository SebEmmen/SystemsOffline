extends StaticBody3D

@export var key_value: String

func interact() -> void:
	print("Hit node: ", name, " | key value: ", key_value)
	get_parent().press_key(key_value)
