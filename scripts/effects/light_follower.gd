extends OmniLight3D

var target_node: Node3D
var offset := Vector3(0, 2.5, 0) # 높이를 2.5로 살짝 낮춰 더 집중되게 변경

@export var shake_speed := 1.5
@export var shake_amount := 0.1

func _process(_delta: float) -> void:
	if is_instance_valid(target_node):
		# 1. 대상 주사위의 전역 위치를 기본으로 설정
		var center_pos = target_node.global_position
		
		# 2. 만약 자식 노드 중에 MeshInstance3D가 있다면 그 메시의 실제 중심점을 보정값으로 사용
		# (모델 파일의 중심점이 어긋나 있는 경우를 대비)
		var mesh = _find_mesh(target_node)
		if mesh:
			# 메시의 전역 트랜스폼을 적용한 실제 중심점 계산
			# (메시 인스턴스가 로컬하게 치우쳐져 있는 경우 보정)
			center_pos = mesh.global_position
		
		# 3. 흔들림 계산
		var time = Time.get_ticks_msec() / 1000.0
		var wobble = Vector3(
			sin(time * shake_speed * 0.7) * shake_amount,
			sin(time * shake_speed * 1.3) * (shake_amount * 0.3),
			cos(time * shake_speed * 0.9) * shake_amount
		)
		
		global_position = center_pos + offset + wobble
	else:
		queue_free()

# 재귀적으로 자식 노드에서 메시를 찾는 헬퍼 함수
func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var res = _find_mesh(child)
		if res:
			return res
	return null
