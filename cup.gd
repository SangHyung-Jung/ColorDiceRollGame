# cup.gd - 주사위 컵의 동작을 제어하는 스크립트 (수정됨)
extends RigidBody3D

# 초기 위치와 회전값을 저장할 변수
var initial_position: Vector3
var initial_rotation: Vector3

# 현재 상태를 나타내는 변수
var is_shaking := false

func _ready() -> void:
	# 노드가 준비되면 초기 위치와 회전값을 저장
	initial_position = global_position
	initial_rotation = rotation_degrees

# 컵을 흔드는 함수 (수정됨)
func shake() -> void:
	if is_shaking: return # 이미 흔들고 있다면 중복 실행 방지
	is_shaking = true
	
	# Tween을 사용하여 부드럽게 흔드는 애니메이션 생성
	var tween = create_tween().set_loops(3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# 위아래 움직임은 줄이고, 회전을 추가하여 소용돌이처럼 섞음
	tween.tween_property(self, "global_position", initial_position + Vector3(0, 0.5, 0), 0.15)
	tween.parallel().tween_property(self, "rotation_degrees:y", initial_rotation.y + 15, 0.15)
	tween.parallel().tween_property(self, "rotation_degrees:z", initial_rotation.z + 5, 0.15)
	
	tween.tween_property(self, "global_position", initial_position, 0.15)
	tween.parallel().tween_property(self, "rotation_degrees:y", initial_rotation.y - 15, 0.15)
	tween.parallel().tween_property(self, "rotation_degrees:z", initial_rotation.z - 5, 0.15)

	# 마지막에 원래 각도로 복귀
	tween.chain().tween_property(self, "rotation_degrees", initial_rotation, 0.1)

	await tween.finished
	is_shaking = false

# 컵을 쏟는 함수
func pour() -> void:
	# Tween을 사용하여 컵을 앞으로 기울여 내용물을 쏟는 애니메이션 생성
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 1. 앞으로 이동하면서
	tween.parallel().tween_property(self, "global_position", initial_position + Vector3(0, 0, -6), 0.6)
	# 2. 컵을 크게 기울임
	tween.parallel().tween_property(self, "rotation_degrees:x", initial_rotation.x - 120, 0.9)
	
	# 쏟은 후 잠시 대기
	tween.tween_interval(1.0)
	
	# 원위치로 복귀하는 애니메이션
	tween.tween_property(self, "global_position", initial_position, 0.5)
	tween.tween_property(self, "rotation_degrees:x", initial_rotation.x, 0.5)
