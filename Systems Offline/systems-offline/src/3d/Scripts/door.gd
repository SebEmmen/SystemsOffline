extends StaticBody3D

var toggle := false
var interactable := true
var locked := true

@export var animation_player: AnimationPlayer


func interact() -> void:
	if locked:
		print("Door is locked!")
		return

	if interactable:
		interactable = false
		toggle = !toggle

		if toggle:
			animation_player.play("open")
		else:
			animation_player.play("close")

		await get_tree().create_timer(1.0, false).timeout
		interactable = true


func unlock() -> void:
	locked = false
	print("Door unlocked!")
