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

# 컵을 흔드는 함수 (빠르고 부드러운 회전 강조)
func shake() -> void:
	if is_shaking: return # 이미 흔들고 있다면 중복 실행 방지
	is_shaking = true
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var duration_per_shake = 0.15 # 속도를 높이기 위해 시간 단축
	var num_shakes = 5 # 흔드는 횟수 증가
	
	for i in range(num_shakes):
		# 위치와 회전 목표를 무작위로 설정
		var random_pos_offset = Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 0.8), randf_range(-1.0, 1.0))
		# Y축 회전(빙글빙글) 범위를 크게 늘림
		var random_rot_offset = Vector3(randf_range(-25, 25), randf_range(-90, 90), randf_range(-25, 25))
		
		tween.tween_property(
			self, "global_position", initial_position + random_pos_offset, duration_per_shake
		)
		tween.parallel().tween_property(
			self, "rotation_degrees", initial_rotation + random_rot_offset, duration_per_shake
		)

	# 흔들기가 모두 끝나면, 부드럽게 원래 상태로 복귀
	tween.chain().tween_property(self, "global_position", initial_position, 0.2)
	tween.parallel().tween_property(self, "rotation_degrees", initial_rotation, 0.2)

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
