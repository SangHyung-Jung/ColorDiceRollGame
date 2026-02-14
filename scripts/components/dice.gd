class_name Dice
extends RigidBody3D

signal roll_finished(value: int, dice_name: String)

@export var dice_color: Color = Color.WHITE
@export var dice_name: String = ""

const DICE_SIZE := 1.2
const ANGULAR_VELOCITY_THRESHOLD := 1.0
const LINEAR_VELOCITY_THRESHOLD := 0.3
const MAX_VELOCITY := 50.0
const MAX_DISTANCE_FROM_ORIGIN := 100.0
const FACE_ANGLE := 90.0
const MAX_ROLL_TIME := 10.0  # 최대 10초 후 강제 정지
const COLLISION_SOUND_COOLDOWN := 0.1 # 충돌 사운드 재생 쿨다운 (초)

var _last_collision_sound_time := 0.0 # 마지막 충돌 사운드 재생 시간
var sides = {
	1: Vector3.UP,        # 1번 면: 위쪽 (Z+)
	6: Vector3.DOWN,      # 6번 면: 아래쪽 (Z-)
	5: Vector3.RIGHT,     # 2번 면: 오른쪽 (X+)
	2: Vector3.LEFT,      # 5번 면: 왼쪽 (X-)
	3: Vector3.FORWARD,   # 3번 면: 앞쪽 (Y+)
	4: Vector3.BACK,      # 4번 면: 뒤쪽 (Y-)
}

var rolling := false
var roll_time := 0.0
var original_position: Vector3

var collider: CollisionShape3D
var mesh_instance: MeshInstance3D

func _init() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	can_sleep = false  # 주사위가 자동으로 sleep되지 않도록
	gravity_scale = 10
	
	mass = 1.5

	# 물리 중심을 약간 랜덤하게 설정하여 주사위가 항상 다르게 굴러가도록
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(
		randf_range(-0.05, 0.05),
		randf_range(-0.05, 0.05),
		randf_range(-0.05, 0.05)
	)

	# freeze_mode 설정하지 않음 - 동적 물리 시뮬레이션 허용
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.absorbent = false
	physics_material_override.bounce = 0.3
	physics_material_override.friction = 0.8

func _ready() -> void:
	if original_position == Vector3.ZERO:
		original_position = position
	add_to_group("dice")
	body_entered.connect(_on_body_entered)

func max_tilt() -> float:
	return cos(deg_to_rad(FACE_ANGLE / float(sides.size())))

# ★ 1. 스폰(리스폰)용 물리: 빠르게 떨어지고 컵 안으로 들어가도록
func setup_physics_for_spawning() -> void:
	print("🎲 ", name, " -> 스폰 물리 적용 (중력 40, 저항 0.1, 반발 0.3)")
	gravity_scale = 40
	linear_damp = 0.1
	angular_damp = 0.1

	if physics_material_override:
		physics_material_override.friction = 0.5
		physics_material_override.bounce = 0.3

# ★ 2. 컵 '내부' 흔들기용 물리: 원본 GitHub 값으로 복원
func apply_inside_cup_physics() -> void:
	gravity_scale = 15
	linear_damp = 0.8
	angular_damp = 0

	if physics_material_override:
		physics_material_override.friction = 0.3
		physics_material_override.bounce = 0.6  # ★ 활발하게 튕기도록

# ★ 3. 컵 '외부' 테이블용 물리: 원본 GitHub 값으로 복원
func apply_outside_cup_physics() -> void:
	gravity_scale = 20
	linear_damp = 0.8  # 저항을 낮춰서 멀리 퍼지도록
	angular_damp = 0.2  # 회전 저항을 낮춰서 더 구르도록

	if physics_material_override:
		physics_material_override.friction = 0.3
		physics_material_override.bounce = 0.5

func start_rolling() -> void:
	rolling = true
	roll_time = 0.0

	# 초기 각속도를 랜덤하게 설정하여 물리적으로 회전하도록
	var x_angular: float
	if randf() < 0.5: # 50% 확률로 음수 범위
		x_angular = randf_range(-25.0, -10.0)
	else: # 50% 확률로 양수 범위
		x_angular = randf_range(10.0, 25.0)

	var y_angular: float
	if randf() < 0.5:
		y_angular = randf_range(-25.0, -10.0)
	else:
		y_angular = randf_range(10.0, 25.0)

	var z_angular: float
	if randf() < 0.5:
		z_angular = randf_range(-25.0, -10.0)
	else:
		z_angular = randf_range(10.0, 25.0)

	angular_velocity = Vector3(x_angular, y_angular, z_angular)

	print("🎲 ", name, " start_rolling - angular_velocity 설정: ", angular_velocity)

func _physics_process(delta: float) -> void:
	if not rolling:
		return

	roll_time += delta

	# 속도 제한 적용
	_apply_velocity_limits()

	# 경계 체크 (카메라 시야에서 너무 멀어지면 강제 정지)
	_check_bounds()

	# _check_bounds에서 강제 정지되었으면 여기서 종료
	if not rolling:
		return

	# 시간 제한 체크 (최대 시간 초과 시 강제 정지)
	if roll_time > MAX_ROLL_TIME:
		print("Dice ", name, " exceeded max roll time, forcing stop")
		_force_stop()
		return

	# 0.5초 전에는 체크하지 않음 (굴러가는 시간 확보)
	if roll_time < 0.5:
		return

	var angular_vel = angular_velocity.length()
	var linear_vel = linear_velocity.length()

	# 디버그: 속도 출력 (주석 처리)
	# if int(roll_time * 10) % 10 == 0:  # 0.1초마다
	# 	print("🎲 ", name, " - 시간: ", roll_time, "s, 선속도: ", linear_vel, ", 각속도: ", angular_vel)

	if angular_vel < ANGULAR_VELOCITY_THRESHOLD and linear_vel < LINEAR_VELOCITY_THRESHOLD:
		_finish_roll()

func _finish_roll() -> void:
	if not rolling:
		return

	rolling = false
	var result = _calculate_face_value()
	roll_finished.emit(result, name)

func _calculate_face_value() -> int:
	# 월드 UP 벡터 (항상 위를 향함)
	var world_up = Vector3.UP
	var best_dot = -2.0
	var result = 1

	print("🎲 ", name, " - 계산 중")

	for value in sides:
		# 주사위 로컬 면 노멀을 월드 좌표로 변환
		var face_normal_world = global_transform.basis * sides[value]
		# 월드 UP과 내적하여 어떤 면이 위를 향하는지 확인
		var dot = world_up.dot(face_normal_world)
		print("  면 ", value, " (", sides[value], "): dot = ", dot, ", world normal: ", face_normal_world)
		if dot > best_dot:
			best_dot = dot
			result = value

	print("  👉 최종 결과: ", result, " (best_dot: ", best_dot, ")")
	return result

func reset_position(new_position: Vector3) -> void:
	global_position = new_position

	# 랜덤 초기 회전 설정
	rotation_degrees = Vector3(
		randf_range(0, 360),
		randf_range(0, 360),
		randf_range(0, 360)
	)

	# 초기 각속도도 랜덤하게 설정하여 떨어지면서 회전하도록
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3(
		randf_range(-5, 5),
		randf_range(-5, 5),
		randf_range(-5, 5)
	)

	rolling = false
	original_position = new_position
	print("🔄 ", name, " reset - pos: ", new_position, ", angular_vel: ", angular_velocity)

func apply_impulse_force(impulse: Vector3, torque: Vector3) -> void:
	apply_central_impulse(impulse)
	apply_torque_impulse(torque)

func show_face(face_value: int) -> void:
	# 주사위를 지정된 면이 위로 오도록 회전
	if face_value in sides:
		var target_rotation = _get_rotation_for_face(face_value)
		print("🎲 ", name, " show_face(", face_value, ") - 설정 전 rotation: ", rotation_degrees, " → 설정 후: ", target_rotation)
		rotation_degrees = target_rotation

		# 다음 프레임까지 기다려서 transform 업데이트 확인
		await get_tree().process_frame
		print("    실제 적용된 rotation: ", rotation_degrees)

func _get_rotation_for_face(face_value: int) -> Vector3:
	# 각 면에 대응하는 회전값 계산
	match face_value:
		1: return Vector3(0, 0, 0)        # UP이 위로 (기본)
		6: return Vector3(180, 0, 0)      # DOWN이 위로
		5: return Vector3(0, 0, -90)      # RIGHT가 위로
		2: return Vector3(0, 0, 90)       # LEFT가 위로
		3: return Vector3(90, 0, 0)       # FORWARD가 위로
		4: return Vector3(-90, 0, 0)      # BACK이 위로
		_: return Vector3.ZERO

func _apply_velocity_limits() -> void:
	# 최대 속도 제한
	if linear_velocity.length() > MAX_VELOCITY:
		linear_velocity = linear_velocity.normalized() * MAX_VELOCITY

	if angular_velocity.length() > MAX_VELOCITY:
		angular_velocity = angular_velocity.normalized() * MAX_VELOCITY

func _check_bounds() -> void:
	# 원점에서 너무 멀어지면 강제로 정지
	var distance_from_origin = global_position.length()
	if distance_from_origin > MAX_DISTANCE_FROM_ORIGIN:
		print("Dice ", name, " too far from origin, forcing stop")
		_force_stop()
		return  # 강제 정지 후 즉시 반환하여 중복 처리 방지

func _force_stop() -> void:
	# 중복 호출 방지
	if not rolling:
		return

	# 강제 정지
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rolling = false

	# 원점 또는 안전한 위치로 이동
	if original_position != Vector3.ZERO:
		global_position = original_position + Vector3(randf_range(-2, 2), 2, randf_range(-2, 2))
	else:
		# 원점 근처로 이동
		global_position = Vector3(randf_range(-10, 10), 2, randf_range(-10, 10))

	print("Dice ", name, " forced to position: ", global_position)

	# 롤 완료 시그널 발송
	var result = _calculate_face_value()
	roll_finished.emit(result, name)

func _on_body_entered(body: Node3D) -> void:
	# 이동 애니메이션 중에는 충돌 사운드를 재생하지 않음
	if collision_layer == 0:
		return

	# 너무 느릴 때는 사운드를 재생하지 않아 소음 방지
	if linear_velocity.length() < 1.5:
		return

	# 쿨다운 체크: 마지막 사운드 재생 후 COLLISION_SOUND_COOLDOWN 초가 지났는지 확인
	var current_time = Time.get_ticks_msec() / 1000.0 # 밀리초를 초 단위로 변환
	if current_time - _last_collision_sound_time < COLLISION_SOUND_COOLDOWN:
		return

	# 사운드 재생 후 마지막 재생 시간 업데이트
	_last_collision_sound_time = current_time

	if body.name == "PhysicsBody": # 컵의 물리 바디와 충돌 시
		SoundManager.play_oneshot("die_on_cup")
	elif body is Dice: # 다른 주사위와 충돌 시
		SoundManager.play_oneshot("die_on_die")


func set_collision_enabled(enabled: bool):
	if collider:
		if enabled:
			# collider의 collision_layer와 collision_mask는 Dice 클래스의 속성이 아니라
			# CollisionShape3D 노드의 속성입니다.
			# Dice 클래스에서 collider는 인스턴스 변수입니다.
			# 해당 collider 인스턴스가 유효한지 확인하고 접근해야 합니다.
			collider.collision_layer = 1
			collider.collision_mask = 1
		else:
			collider.collision_layer = 0
			collider.collision_mask = 0
	else:
		# collider가 아직 초기화되지 않았거나 누락된 경우를 대비한 경고
		push_warning("Collider not found for Dice: ", name, ". Cannot set collision.")
