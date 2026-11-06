extends Skeleton3D

func _ready() -> void:
	var idx := find_bone("LeftShoulder")
	if idx == -1:
		push_warning("LeftShoulder bone not found")
		return
	set_bone_pose_scale(idx, Vector3.ONE * 0.001)

func _process(_delta: float) -> void:
	var idx := find_bone("LeftShoulder")
	if idx != -1:
		set_bone_pose_scale(idx, Vector3.ONE * 0.001)
