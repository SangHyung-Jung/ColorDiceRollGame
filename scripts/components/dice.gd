class_name Dice
extends RigidBody3D

signal roll_finished(value: int, dice_name: String)

@export var dice_color: Color = Color.WHITE
@export var dice_name: String = ""

const DICE_SIZE := 1.2
const ANGULAR_VELOCITY_THRESHOLD := 1.0
const LINEAR_VELOCITY_THRESHOLD := 0.3
const MAX_VELOCITY := 50.0
const MAX_DISTANCE_FROM_ORIGIN := 30.0
const FACE_ANGLE := 90.0
const MAX_ROLL_TIME := 10.0  # 최대 10초 후 강제 정지

var face_markers: Array[Node3D] = []

var rolling := false
var roll_time := 0.0
var original_position: Vector3

var collider: CollisionShape3D
var mesh_instance: MeshInstance3D

func _init() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	can_sleep = false
	gravity_scale = 10

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(
		randf_range(-0.05, 0.05),
		randf_range(-0.05, 0.05),
		randf_range(-0.05, 0.05)
	)

	physics_material_override = PhysicsMaterial.new()
	physics_material_override.absorbent = false
	physics_material_override.bounce = 0.3
	physics_material_override.friction = 0.8

func _ready() -> void:
	if original_position == Vector3.ZERO:
		original_position = position
	add_to_group("dice")
	
	# 자식 노드를 순회하여 'Face_X' 마커를 찾습니다.
	for child in get_children():
		if child.name.begins_with("Face_"):
			face_markers.append(child)
	
	if face_markers.size() != 6:
		push_error("Dice '%s' must have exactly 6 child nodes named 'Face_1' through 'Face_6'." % name)


func max_tilt() -> float:
	# This function might need adjustment if it was dependent on the old 'sides' dictionary
	# For now, returning a sensible default.
	return cos(deg_to_rad(FACE_ANGLE / 6.0))

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
	print("🎲 ", name, " -> 컵 내부 흔들기 물리 적용 (중력 40, 저항 0.5, 반발 0.6)")
	gravity_scale = 40
	linear_damp = 0.5
	angular_damp = 0.1

	if physics_material_override:
		physics_material_override.friction = 0.4
		physics_material_override.bounce = 0.6  # ★ 활발하게 튕기도록

# ★ 3. 컵 '외부' 테이블용 물리: 원본 GitHub 값으로 복원
func apply_outside_cup_physics() -> void:
	print("🎲 ", name, " -> 테이블 물리 적용 (중력 40, 저항 2.0)")
	gravity_scale = 40
	linear_damp = 2.0  # 저항을 높여서 빠르게 정착
	angular_damp = 5.0  # 회전 저항을 높여서 빠르게 멈춤

	if physics_material_override:
		physics_material_override.friction = 1.2
		physics_material_override.bounce = 0.2

func start_rolling() -> void:
	rolling = true
	roll_time = 0.0

	# 초기 각속도를 랜덤하게 설정하여 물리적으로 회전하도록
	angular_velocity = Vector3(
		randf_range(-10, 10),
		randf_range(-10, 10),
		randf_range(-10, 10)
	)

	print("🎲 ", name, " start_rolling - angular_velocity 설정: ", angular_velocity)

func _physics_process(delta: float) -> void:
	if not rolling:
		return

	roll_time += delta

	_apply_velocity_limits()
	_check_bounds()

	if not rolling:
		return

	if roll_time > MAX_ROLL_TIME:
		print("Dice ", name, " exceeded max roll time, forcing stop")
		_force_stop()
		return

	if roll_time < 0.5:
		return

	var angular_vel = angular_velocity.length()
	var linear_vel = linear_velocity.length()

	if angular_vel < ANGULAR_VELOCITY_THRESHOLD and linear_vel < LINEAR_VELOCITY_THRESHOLD:
		_finish_roll()

func _finish_roll() -> void:
	if not rolling:
		return

	rolling = false
	var result = _calculate_face_value()
	roll_finished.emit(result, name)

func _calculate_face_value() -> int:
	if face_markers.is_empty():
		push_error("Cannot calculate face value: No face markers found.")
		return 1

	var best_dot = -2.0
	var result = 1
	
	print("🎲 ", name, " - 계산 중 (Marker3D 방식)")

	for marker in face_markers:
		# 마커의 Z축(앞쪽)이 바깥을 향한다고 가정하고 월드 좌표로 변환합니다.
		# Godot에서 노드의 Z축은 '앞'을 의미하며, 보통 -Z가 정면 방향입니다.
		# 마커를 모델에 배치할 때 파란색 화살표(-Z)가 면의 바깥쪽을 향하게 해야 합니다.
		var marker_forward_world = -marker.global_transform.basis.z
		var dot = Vector3.UP.dot(marker_forward_world)
		
		# print("  마커 ", marker.name, ": dot = ", dot)
		if dot > best_dot:
			best_dot = dot
			result = int(marker.name.split("_")[1])

	print("  👉 최종 결과: ", result, " (best_dot: ", best_dot, ")")
	return result

func reset_position(new_position: Vector3) -> void:
	global_position = new_position
	rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	rolling = false
	original_position = new_position
	print("🔄 ", name, " reset - pos: ", new_position, ", angular_vel: ", angular_velocity)

func apply_impulse_force(impulse: Vector3, torque: Vector3) -> void:
	apply_central_impulse(impulse)
	apply_torque_impulse(torque)

func show_face(face_value: int) -> void:
	# TODO: 이 기능은 Marker3D 접근법으로 재구현해야 합니다.
	# 현재는 주사위 값 계산이 더 중요하므로, 이 기능은 일시적으로 비활성화됩니다.
	# print("🎲 ", name, " show_face(", face_value, ") - 기능이 일시적으로 비활성화되었습니다.")
	pass

func _apply_velocity_limits() -> void:
	if linear_velocity.length() > MAX_VELOCITY:
		linear_velocity = linear_velocity.normalized() * MAX_VELOCITY
	if angular_velocity.length() > MAX_VELOCITY:
		angular_velocity = angular_velocity.normalized() * MAX_VELOCITY

func _check_bounds() -> void:
	var distance_from_origin = global_position.length()
	if distance_from_origin > MAX_DISTANCE_FROM_ORIGIN:
		print("Dice ", name, " too far from origin, forcing stop")
		_force_stop()
		return

func _force_stop() -> void:
	if not rolling:
		return

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rolling = false

	if original_position != Vector3.ZERO:
		global_position = original_position + Vector3(randf_range(-2, 2), 2, randf_range(-2, 2))
	else:
		global_position = Vector3(randf_range(-10, 10), 2, randf_range(-10, 10))

	print("Dice ", name, " forced to position: ", global_position)

	var result = _calculate_face_value()
	roll_finished.emit(result, name)
