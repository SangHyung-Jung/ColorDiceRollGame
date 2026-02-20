extends OmniLight3D

var target_node: Node3D
var offset := Vector3(0, 4, 0)

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		# 주사위의 회전은 무시하고, 전역 위치(global_position)만 가져와서 오프셋을 더함
		global_position = target_node.global_position + offset
	else:
		# 대상이 사라지면 조명도 삭제
		queue_free()
