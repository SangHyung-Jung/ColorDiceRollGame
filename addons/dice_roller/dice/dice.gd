class_name Dice
extends RigidBody3D
@export var pips_texture_original: Texture2D
@export var dice_color := Color.BROWN:
		set(value):
			dice_color = value
			if is_node_ready():
				call_deferred("_update_visuals")

@onready var original_position := position

var sides = {}
var highlight_orientation = {}

const dice_size := 0.65
const dice_density := 1.0
const ANGULAR_VELOCITY_THRESHOLD := 1.
const LINEAR_VELOCITY_THRESHOLD := 0.3 * dice_size
const mounted_elevation = 0.8 * dice_size
const face_angle := 90.0

const MAX_VELOCITY := 50.0               # 최대 속도 제한
const MAX_DISTANCE_FROM_ORIGIN := 30.0  # 원점에서 최대 거리

func max_tilt():
	return cos(deg_to_rad(face_angle/float(sides.size())))

var rolling := false
var roll_time := 0.0

signal roll_finished(int)

func _init() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	can_sleep = true
	gravity_scale = 10
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.absorbent = true
	physics_material_override.bounce = 0.2
	physics_material_override.friction = 1.5

@onready var collider : CollisionShape3D = $Collider
@onready var highlight_face : Node3D = $FaceHighligth
@onready var mesh = $DiceMesh

func _adjust_to_size():
	mass = dice_density * dice_size **3
	# 충돌 마진 설정으로 더 정확한 충돌 감지
	if collider and collider.shape:
		collider.shape.margin = 0.04  # 기본값보다 약간 큼

func apply_inside_cup_physics() -> void:
	# 컵 안에서는 중력이 거의 없거나 약하게 만들어 떠다니는 느낌을 줌
	gravity_scale = 40                    # 40 → 30으로 감소
	# 공기 저항(감속)을 줄여 더 활발하게 움직이게 함
	linear_damp = 0.5                     # 0.1 → 0.3으로 증가 (더 빨리 감속)
	angular_damp = 0.1                    # 0.5 → 0.8로 증가
	
	if physics_material_override:
		physics_material_override.friction = 0.5   # 0.1 → 0.2
		physics_material_override.bounce = 0.5     # 0.7 → 0.3으로 대폭 감소

func apply_outside_cup_physics() -> void:
	gravity_scale = 40
	linear_damp = 0.01 # -1은 프로젝트 기본값 사용
	angular_damp = 3.0
	if physics_material_override:
		physics_material_override.friction = 1.0   # 0.6 → 2.0 (높은 마찰력)
		physics_material_override.bounce = 0.1     # 기본값 → 0.1 (거의 안 튕김)

func _ready():
	original_position = position
	_adjust_to_size()
	self.sleeping_state_changed.connect(_on_sleeping_state_changed)
	
	call_deferred("_update_visuals")
	
	stop()
	
	mesh.scale = Vector3(dice_size, dice_size, dice_size)
	self.angular_damp = 1.2
	continuous_cd = true
	apply_inside_cup_physics()
	
	
func _update_visuals():
	if not pips_texture_original:
		return
	
	var unique_material = StandardMaterial3D.new()
	unique_material.resource_local_to_scene = true

	var pips_color: Color
	if dice_color.is_equal_approx(Color.WHITE):
		pips_color = Color.BLACK
	else:
		pips_color = Color.WHITE

	var new_texture = _generate_dice_texture(dice_color, pips_color)
	if not new_texture:
		printerr("Dice '", name, "': Failed to generate new texture.")
		return

	unique_material.albedo_texture = new_texture
	unique_material.albedo_color = Color.WHITE
	
	mesh.material_override = unique_material

func _generate_dice_texture(body_color: Color, pips_color: Color) -> ImageTexture:
	var source_image: Image = pips_texture_original.get_image()
	if source_image == null or source_image.is_empty():
		return null

	if source_image.is_compressed():
		if source_image.decompress() != OK:
			printerr("Failed to decompress source image for dice '", name, "'")
			return null

	source_image.convert(Image.FORMAT_RGBA8)

	var new_image: Image = Image.create(source_image.get_width(), source_image.get_height(), false, Image.FORMAT_RGBA8)

	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			var original_pixel = source_image.get_pixel(x, y)
			
			if original_pixel.v < 0.5:
				new_image.set_pixel(x, y, pips_color)
			else:
				new_image.set_pixel(x, y, body_color)
	
	return ImageTexture.create_from_image(new_image)


func stop():
	dehighlight()
	freeze = true
	position = original_position
	rotation = randf_range(0, 2*PI)*Vector3(1.,1.,1.)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func roll():
	"""Roll the dice"""
	dehighlight()
	linear_velocity = Vector3(-dice_size, 0, -dice_size)
	angular_velocity = Vector3.ZERO
	freeze = false
	sleeping = false
	lock_rotation = false
	roll_time = 0
	rolling = true
	var torque_strength = mass * 10.0
	apply_torque_impulse( torque_strength * Vector3(
		randf_range(-1.,+1.),
		randf_range(-1.,+1.),
		randf_range(-1.,+1.)
	))

func _process(_delta):
	if not rolling: return
	roll_time += _delta

	# ★ 속도 제한
	if linear_velocity.length() > MAX_VELOCITY:
		linear_velocity = linear_velocity.normalized() * MAX_VELOCITY
		print("⚠️ ", name, " 속도 제한 적용: ", linear_velocity.length())
	
	# ★ 거리 제한 (원점에서 너무 멀리 가면 강제 정지)
	if global_position.length() > MAX_DISTANCE_FROM_ORIGIN:
		print("⚠️ ", name, " 경계 밖으로 나감 - 강제 정지")
		_force_stop()
		return


func _force_stop():
	"""주사위를 강제로 정지시킵니다"""
	rolling = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	
	# 안전한 위치로 이동 (필요시)
	if global_position.length() > MAX_DISTANCE_FROM_ORIGIN:
		global_position = Vector3(
			randf_range(-5, 5),
			2,
			randf_range(-5, 5)
		)
	
	# 결과 결정 (랜덤하게)
	var random_face = randi_range(1, 6)
	print("🎲 ", name, " 강제 정지 결과: ", random_face)
	roll_finished.emit(random_face)

# ★★ 수정된 부분: 주사위가 멈추는 방식을 변경합니다. ★★
func _on_sleeping_state_changed():
	if not rolling or not self.sleeping:
		return

	var side = upper_side()

	print("Dice %s solved by sleeping [%s] - %.02fs"%([name, side, roll_time]))
	freeze = true

	highlight()
	roll_finished.emit(side)

func upper_side():
	"Returns which dice side is up, or 0 when none is clear"
	var highest_y := -INF
	var highest_side := 0
	for side in sides:
		var y = to_global(sides[side]).y
		if y < highest_y: continue
		highest_y = y
		highest_side = side
			
	return highest_side

func face_up_transform(value) -> Transform3D:
	"""Returns the 3D tranform to put the given value up"""
	var face_normal = (to_global(sides[value])-global_position).normalized()
	var cross = face_normal.cross(Vector3.UP).normalized()
	var angle = face_normal.angle_to(Vector3.UP)
	var rotated := Transform3D(transform)
	if cross.length_squared()<0.1:
		cross = Vector3.FORWARD
	rotated.basis = rotated.basis.rotated(cross.normalized(), angle)
	return rotated

func show_face(value):
	"""Shows a given face by rotating it up"""
	assert(value in sides)
	dehighlight()
	rolling = true
	const show_face_animation_time := .3
	var rotated := face_up_transform(value)
	var tween: Tweener = create_tween().tween_property(
		self, "transform", rotated, show_face_animation_time
	)
	await tween.finished
	rolling = false
	highlight()
	roll_finished.emit(value)

func highlight():
	# highlight_face.visible = true # 유저 요청으로 비활성화
	pass

func dehighlight() -> void:
	highlight_face.visible = false
