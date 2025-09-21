## 물리 기반 주사위 컵 시스템
## 실감나는 흔들기와 쏟기 애니메이션을 제공하며,
## 두 가지 흔들기 패턴(원형/대각선)을 지원합니다.
## 주사위와의 물리적 상호작용도 관리합니다.
extends Node3D

# 사용 가능한 흔들기 패턴들
enum ShakeType {
	CIRCULAR,  # 원형 궤도로 흔들기 (부드러운 패턴)
	DIAGONAL   # 대각선 왕복 흔들기 (역동적인 패턴)
}
# 현재 사용할 흔들기 방식 (에디터에서 변경 가능)
@export var current_shake_type: ShakeType = ShakeType.DIAGONAL


# === 컵 상태 변수들 ===
var initial_position: Vector3  # 컵의 초기 위치 (원위치 복귀용)
var initial_rotation: Vector3  # 컵의 초기 회전각 (원위치 복귀용)
var is_shaking := false        # 현재 흔들기 중인지 여부
var shake_time := 0.0          # 흔들기 애니메이션 누적 시간

# === 흔들기 애니메이션 파라미터 ===
const SHAKE_SPEED := 18.0      # 흔들기 속도 (더 빠르게)
const TILT_AMOUNT := 20.0      # 기울기 정도 (더 크게)
const SHAKE_RADIUS := 1.0      # 원형 흔들기 반지름 (더 크게)
const VERTICAL_SHAKE := 0.8    # 수직 흔들기 강도 (Y축 움직임)
const DICE_SHAKE_FORCE := 3.0  # 흔들기 중 주사위에 가할 힘

# 대각선 흔들기를 위한 이동 벡터
# 우측 상단에서 좌측 하단으로 움직이는 3D 방향
const DIAGONAL_VECTOR := Vector3(1.15, 1.0, -1.15)

# 컵 내부 영역 감지를 위한 Area3D (주사위 진입/이탈 감지)
@onready var inside_area: Area3D = $PhysicsBody/InsideArea

## 컵 초기화 - 위치 저장 및 시그널 연결
func _ready() -> void:
	# 원래 위치와 회전각 저장 (애니메이션 후 복귀용)
	initial_position = global_position
	initial_rotation = rotation_degrees

	# 주사위가 컵 안팎으로 이동할 때의 이벤트 연결
	inside_area.body_entered.connect(_on_body_entered_cup)
	inside_area.body_exited.connect(_on_body_exited_cup)

## 매 프레임마다 흔들기 애니메이션 처리
func _process(delta: float) -> void:
	if is_shaking:
		_process_shaking(delta)

## 선택된 흔들기 패턴에 따라 애니메이션 실행
## @param delta: 프레임 델타 시간
func _process_shaking(delta: float) -> void:
	# 흔들기 시간 누적 (속도 조절)
	shake_time += delta * SHAKE_SPEED

	# 설정된 흔들기 타입에 따라 다른 애니메이션 실행
	match current_shake_type:
		ShakeType.CIRCULAR:
			# 원형 궤도 이동 계산 (Y축 움직임 추가)
			var offset_x = cos(shake_time) * SHAKE_RADIUS
			var offset_z = sin(shake_time) * SHAKE_RADIUS
			var offset_y = sin(shake_time * 2.3) * VERTICAL_SHAKE  # 수직 진동 추가
			global_position = initial_position + Vector3(offset_x, offset_y, offset_z)

			# 원형 움직임에 맞는 자연스러운 기울기 애니메이션
			var tilt_x = sin(shake_time * 0.9) * TILT_AMOUNT
			var tilt_z = cos(shake_time) * TILT_AMOUNT
			rotation_degrees.x = initial_rotation.x + tilt_x
			rotation_degrees.z = initial_rotation.z + tilt_z

		ShakeType.DIAGONAL:
			# 대각선 왕복 움직임 (역동적인 패턴 + Y축 움직임)
			var movement_factor = sin(shake_time)
			var vertical_factor = sin(shake_time * 1.7) * VERTICAL_SHAKE  # 다른 주기로 수직 움직임
			var movement_vector = DIAGONAL_VECTOR * movement_factor + Vector3(0, vertical_factor, 0)
			global_position = initial_position + movement_vector

			# 대각선 움직임에 맞는 동적 기울기
			var tilt = TILT_AMOUNT * movement_factor
			rotation_degrees.z = initial_rotation.z + tilt
			rotation_degrees.x = initial_rotation.x - tilt

	# 흔들기 중 컵 내부 주사위들에 힘 적용
	_apply_shake_forces_to_dice()
		


## 흔들기 시작 - 이미 흔들고 있다면 무시
func start_shaking() -> void:
	if is_shaking:
		return  # 이미 흔들기 중
	is_shaking = true
	shake_time = 0.0  # 시간 초기화

## 흔들기 중지 및 원위치 복귀 (비동기)
## 부드러운 트위닝으로 원래 위치로 돌아갑니다
func stop_shaking() -> void:
	if not is_shaking:
		return  # 이미 중지된 상태
	is_shaking = false

	# 원위치로 돌아가는 부드러운 애니메이션
	var return_tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tween.parallel().tween_property(self, "global_position", initial_position, 0.2)
	return_tween.parallel().tween_property(self, "rotation_degrees", initial_rotation, 0.2)

	# 애니메이션 완료까지 대기
	await return_tween.finished

## 주사위가 컵 안으로 들어왔을 때 호출
## 주사위의 물리 속성을 컵 내부에 맞게 조정
func _on_body_entered_cup(body: Node3D) -> void:
	if body is Dice:
		body.apply_inside_cup_physics()  # 컵 내부 물리 속성 적용

## 주사위가 컵에서 나갔을 때 호출
## 주사위의 물리 속성을 컵 외부에 맞게 조정
func _on_body_exited_cup(body: Node3D) -> void:
	if body is Dice:
		body.apply_outside_cup_physics()  # 컵 외부 물리 속성 적용
		
## 컵 쏟기 애니메이션 (비동기)
## 컵을 기울여서 주사위들을 밖으로 쏟는 동작
func pour() -> void:
	# 1단계: 컵 기울이기 및 좌측 이동
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var pour_duration = 0.5
	var snap_x_duration = 0.6
	tween.tween_property(self, "rotation_degrees:z", initial_rotation.z + 130, pour_duration)  # Z축 기울기
	tween.parallel().tween_property(self, "rotation_degrees:y", initial_rotation.y - 20, pour_duration)  # Y축 약간 회전
	tween.parallel().tween_property(self, "global_position:x", initial_position.x - 5, snap_x_duration)  # 좌측으로 이동
	await tween.finished

	# 2단계: 원위치 복귀
	var return_tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var return_duration = 1
	return_tween.parallel().tween_property(self, "global_position:x", initial_position.x + 10, return_duration)  # 우측으로 복귀
	return_tween.parallel().tween_property(self, "rotation_degrees", initial_rotation, return_duration)  # 회전 복귀

## 컵을 원래 상태로 즉시 리셋
## 새 라운드 시작 시 호출됩니다
func reset() -> void:
	global_position = initial_position
	rotation_degrees = initial_rotation

## 흔들기 중에 컵 내부 주사위들에 힘을 가해 더 활발하게 움직이게 함
func _apply_shake_forces_to_dice() -> void:
	# 컵 안에 있는 주사위들 찾기
	var dice_in_cup = inside_area.get_overlapping_bodies()

	# 매 프레임마다 적용하면 너무 강하므로 간헐적으로 적용
	if int(shake_time * 10) % 3 == 0:  # 0.3초마다 적용
		for body in dice_in_cup:
			if body.has_method("apply_central_impulse"):
				# 컵 움직임 방향에 따른 힘 계산
				var shake_direction = Vector3.ZERO
				match current_shake_type:
					ShakeType.CIRCULAR:
						shake_direction = Vector3(
							-sin(shake_time) * DICE_SHAKE_FORCE,
							cos(shake_time * 2.3) * DICE_SHAKE_FORCE * 0.5,
							cos(shake_time) * DICE_SHAKE_FORCE
						)
					ShakeType.DIAGONAL:
						var factor = cos(shake_time)
						shake_direction = Vector3(
							DIAGONAL_VECTOR.x * factor * DICE_SHAKE_FORCE,
							sin(shake_time * 1.7) * DICE_SHAKE_FORCE * 0.6,
							DIAGONAL_VECTOR.z * factor * DICE_SHAKE_FORCE
						)

				# 랜덤 요소 추가로 더 자연스러운 움직임
				shake_direction += Vector3(
					randf_range(-2, 2),
					randf_range(-1, 3),
					randf_range(-2, 2)
				)

				body.apply_central_impulse(shake_direction)

				# 회전력도 추가
				if body.has_method("apply_torque_impulse"):
					body.apply_torque_impulse(Vector3(
						randf_range(-5, 5),
						randf_range(-3, 3),
						randf_range(-5, 5)
					))
