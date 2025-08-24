# cup.gd - 주사위 컵의 동작을 제어하는 스크립트 (섞기 방식 선택 기능 추가)
extends RigidBody3D

# --- 섞기 방식을 선택하기 위한 Enum과 Export 변수 ---
enum ShakeType { 
	CIRCULAR,  # 원형 섞기
	DIAGONAL   # 대각선 섞기
}
@export var current_shake_type: ShakeType = ShakeType.DIAGONAL


var initial_position: Vector3
var initial_rotation: Vector3

var is_shaking := false
var shake_time := 0.0

# --- 공용 및 원형 섞기 파라미터 ---
const SHAKE_SPEED := 15.0
const TILT_AMOUNT := 15.0
const SHAKE_RADIUS := 1.0

# --- 대각선 섞기 파라미터 ---
# 우측 상단(X:+, Y:+, Z:-)에서 좌측 하단(X:-, Y:-, Z:+)으로 움직이는 벡터
const DIAGONAL_VECTOR := Vector3(1.3, 1.0, -1.3)

@onready var inside_area: Area3D = $InsideArea

func _ready() -> void:
	initial_position = global_position
	initial_rotation = rotation_degrees
	
	inside_area.body_entered.connect(_on_body_entered_cup)
	inside_area.body_exited.connect(_on_body_exited_cup)

func _process(delta: float) -> void:
	if is_shaking:
		_process_shaking(delta)

func _process_shaking(delta: float) -> void:
	shake_time += delta * SHAKE_SPEED
	
	# current_shake_type 값에 따라 다른 동작을 실행
	match current_shake_type:
		ShakeType.CIRCULAR:
			# 1-A. 원형 경로 계산
			var offset_x = cos(shake_time) * SHAKE_RADIUS
			var offset_z = sin(shake_time) * SHAKE_RADIUS
			global_position = initial_position + Vector3(offset_x, 0, offset_z)
			
			# 1-B. 원형 기울기 애니메이션
			var tilt_x = sin(shake_time * 0.9) * TILT_AMOUNT
			var tilt_z = cos(shake_time) * TILT_AMOUNT
			rotation_degrees.x = initial_rotation.x + tilt_x
			rotation_degrees.z = initial_rotation.z + tilt_z

		ShakeType.DIAGONAL:
			# 2-A. 대각선 왕복 경로 계산 (sin 함수 이용)
			var movement_factor = sin(shake_time)
			global_position = initial_position + DIAGONAL_VECTOR * movement_factor
			
			# 2-B. 대각선 기울기 애니메이션
			# 움직임에 맞춰 Z축과 X축을 중심으로 기울어짐
			var tilt = TILT_AMOUNT * movement_factor
			rotation_degrees.z = initial_rotation.z + tilt
			rotation_degrees.x = initial_rotation.x - tilt


func start_shaking() -> void:
	if is_shaking: return
	is_shaking = true
	shake_time = 0.0

func stop_shaking() -> void:
	if not is_shaking: return
	is_shaking = false
	
	var return_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tween.parallel().tween_property(self, "global_position", initial_position, 0.1)
	return_tween.parallel().tween_property(self, "rotation_degrees", initial_rotation, 0.1)
	
	await return_tween.finished

# ... _on_body_entered_cup, _on_body_exited_cup, pour, reset 함수는 기존과 동일 ...
func _on_body_entered_cup(body: Node3D) -> void:
	if body is Dice:
		body.apply_inside_cup_physics()
func _on_body_exited_cup(body: Node3D) -> void:
	if body is Dice:
		body.apply_outside_cup_physics()
func pour() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var pour_duration = 0.4
	var snap_x_duration = 0.5
	tween.tween_property(self, "rotation_degrees:z", initial_rotation.z + 130, pour_duration)
	tween.parallel().tween_property(self, "rotation_degrees:y", initial_rotation.y - 20, pour_duration)
	tween.parallel().tween_property(self, "global_position:x", initial_position.x - 5, snap_x_duration)
	await tween.finished
	var return_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var return_duration = 1
	return_tween.parallel().tween_property(self, "global_position:x", initial_position.x + 10, return_duration)
	return_tween.parallel().tween_property(self, "rotation_degrees", initial_rotation, return_duration)
func reset() -> void:
	global_position = initial_position
	rotation_degrees = initial_rotation
