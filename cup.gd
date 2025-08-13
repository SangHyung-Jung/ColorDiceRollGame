# cup.gd - 주사위 컵의 동작을 제어하는 스크립트 (연속 흔들기 적용)
extends RigidBody3D

var initial_position: Vector3
var initial_rotation: Vector3

var is_shaking := false
var shake_tween: Tween # 현재 실행중인 흔들기 트윈을 저장할 변수

func _ready() -> void:
	# RigidBody3D 모드는 Kinematic으로 .tscn 파일에서 직접 설정됩니다.
	initial_position = global_position
	initial_rotation = rotation_degrees

# 흔들기 시작 (무한 반복)
func start_shaking() -> void:
	if is_shaking: return
	is_shaking = true
	
	# 기존 트윈이 있다면 확실히 제거
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	
	shake_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var duration_per_shake = 0.2
	
	# 무한 루프 트윈 설정
	shake_tween.tween_callback(func():
		var random_pos_offset = Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 0.8), randf_range(-1.0, 1.0))
		var random_rot_offset = Vector3(randf_range(-25, 25), randf_range(-90, 90), randf_range(-25, 25))
		
		var move_tween = get_tree().create_tween()
		move_tween.parallel().tween_property(self, "global_position", initial_position + random_pos_offset, duration_per_shake)
		move_tween.parallel().tween_property(self, "rotation_degrees", initial_rotation + random_rot_offset, duration_per_shake)
	)
	shake_tween.tween_interval(duration_per_shake)

# 흔들기 중지 및 원위치 복귀
func stop_shaking() -> void:
	if not is_shaking: return
	
	# 진행중인 흔들기 트윈을 중지
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		shake_tween = null
	
	# 원위치로 돌아가는 새로운 트윈 생성
	var return_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tween.parallel().tween_property(self, "global_position", initial_position, 0.2)
	return_tween.parallel().tween_property(self, "rotation_degrees", initial_rotation, 0.2)
	
	# 돌아가는 애니메이션이 끝날 때까지 대기
	await return_tween.finished
	is_shaking = false

# 컵을 쏟는 함수 (단순하고 강력하게 수정)
func pour() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var pour_duration = 0.35 # 쏟는 시간 대폭 단축 (매우 빠르게)
	
	# Z축을 기준으로 컵을 매우 깊게 기울여 확실히 쏟음
	tween.tween_property(self, "rotation_degrees:z", initial_rotation.z + 130, pour_duration)
	# 약간 안쪽을 보도록 Y축을 살짝 회전
	tween.parallel().tween_property(self, "rotation_degrees:y", initial_rotation.y, pour_duration)
	# 동시에, 왼쪽으로 짧고 빠르게 이동하여 '스냅' 효과를 줌
	tween.parallel().tween_property(self, "global_position:x", initial_position.x - 6, 0.5)

func reset() -> void:
	global_position = initial_position
	rotation_degrees = initial_rotation
