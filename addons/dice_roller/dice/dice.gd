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

const dice_size := 1.2
const dice_density := 1.0
const ANGULAR_VELOCITY_THRESHOLD := 1.
const LINEAR_VELOCITY_THRESHOLD := 0.3 * dice_size
const mounted_elevation = 0.8 * dice_size
const face_angle := 90.0

const MAX_VELOCITY := 50.0
const MAX_DISTANCE_FROM_ORIGIN := 30.0

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
	
	# 1. 스폰 시 사용할 기본 중력 (약함)
	gravity_scale = 10
	
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.absorbent = true
	# 2. 기본 반발력 0
	physics_material_override.bounce = 0.0
	physics_material_override.friction = 1.5

@onready var collider : CollisionShape3D = $Collider
@onready var highlight_face : MeshInstance3D = $FaceHighligth
@onready var mesh = $DiceMesh

func _adjust_to_size():
	mass = dice_density * dice_size **3
	if collider and collider.shape:
		collider.shape.margin = 0.04

# ★ 1. 스폰(리스폰)용 물리: 중력(10)은 약하게, 저항(5)은 강하게, 반발(0)은 없게
func apply_spawning_physics() -> void:
	print("🎲 ", name, " -> 스폰 물리 적용 (중력 10, 저항 5, 반발 0)")
	gravity_scale = 10
	linear_damp = 5.0
	angular_damp = 5.0
	
	if physics_material_override:
		physics_material_override.friction = 1.0
		physics_material_override.bounce = 0.0

# ★ 2. 컵 '내부' 흔들기용 물리: 원본 GitHub 값으로 복원
func apply_inside_cup_physics() -> void:
	print("🎲 ", name, " -> 컵 내부 흔들기 물리 적용 (중력 40, 저항 0.5, 반발 0.5)")
	gravity_scale = 40
	linear_damp = 0.5
	angular_damp = 0.1
	
	if physics_material_override:
		physics_material_override.friction = 0.5
		physics_material_override.bounce = 0.5 # ★ 활발하게 튕기도록 복원

# ★ 3. 컵 '외부' 테이블용 물리: 원본 GitHub 값으로 복원
func apply_outside_cup_physics() -> void:
	print("🎲 ", name, " -> 테이블 물리 적용 (중력 40, 저항 0.01)")
	gravity_scale = 40
	linear_damp = 0.01
	angular_damp = 3.0
	if physics_material_override:
		physics_material_override.friction = 1.0
		physics_material_override.bounce = 0.1

func _ready():
	original_position = position
	_adjust_to_size()
	self.sleeping_state_changed.connect(_on_sleeping_state_changed)
	
	call_deferred("_update_visuals")
	
	stop()
	
	self.angular_damp = 1.2
	continuous_cd = true
	
	# ★ 스폰 시에는 '스포닝' 물리만 적용
	apply_spawning_physics()
	
	if highlight_face:
		highlight_face.visible = false
	
	
func _update_visuals():
	# (Blender 모델 사용하므로 텍스처 생성 안 함)
	return

static func generate_dice_texture(pips_texture: Texture2D, body_color: Color, pips_color: Color) -> ImageTexture:
	var source_image: Image = pips_texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	if source_image.is_compressed():
		if source_image.decompress() != OK:
			printerr("Failed to decompress source image for dice")
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

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func stop():
	dehighlight()
	freeze = true
	position = original_position
	rotation = randf_range(0, 2*PI)*Vector3(1.,1.,1.)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func roll():
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
	if linear_velocity.length() > MAX_VELOCITY:
		linear_velocity = linear_velocity.normalized() * MAX_VELOCITY
		print("⚠️ ", name, " 속도 제한 적용: ", linear_velocity.length())
	if global_position.length() > MAX_DISTANCE_FROM_ORIGIN:
		print("⚠️ ", name, " 경계 밖으로 나감 - 강제 정지")
		_force_stop()
		return

func _force_stop():
	rolling = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	if global_position.length() > MAX_DISTANCE_FROM_ORIGIN:
		global_position = Vector3(
			randf_range(-5, 5),
			2,
			randf_range(-5, 5)
		)
	var random_face = randi_range(1, 6)
	print("🎲 ", name, " 강제 정지 결과: ", random_face)
	roll_finished.emit(random_face)

func _on_sleeping_state_changed():
	if not rolling: return
	if not sleeping: return
	
	var result = get_result()
	if result > 0:
		highlight(result)
		roll_finished.emit(result)
		rolling = false

func get_result() -> int:
	if sides.is_empty():
		push_warning("Dice '", name, "' has no 'sides' defined yet.")
		return -1
		
	for number in sides:
		var side_vector: Vector3 = sides[number]
		var world_up = Vector3.UP
		var side_global = global_transform.basis * side_vector
		
		var dot = side_global.normalized().dot(world_up)
		
		if dot > max_tilt():
			return number
	
	return 0

func highlight(number: int):
	if not highlight_face: return
	highlight_face.visible = true
	
	if not number in highlight_orientation: return
	
	var orientation: Vector3 = highlight_orientation[number]
	highlight_face.look_at(global_transform.basis * orientation + global_position, Vector3.UP)

func dehighlight():
	if highlight_face:
		highlight_face.visible = false

func show_face(number: int):
	"""주사위를 특정 면이 위로 오도록 회전시킵니다"""
	if not number in sides:
		return
	
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	var target_up_local: Vector3 = sides[number].normalized()
	
	var y_axis = target_up_local
	var x_axis: Vector3
	var z_axis: Vector3
	
	if abs(y_axis.dot(Vector3.UP)) > 0.999:
		if y_axis.y > 0:
			x_axis = Vector3.RIGHT
			z_axis = Vector3.FORWARD
		else:
			x_axis = Vector3.RIGHT
			z_axis = Vector3.BACK
	else:
		x_axis = y_axis.cross(Vector3.UP).normalized()
		z_axis = x_axis.cross(y_axis).normalized()

	var new_basis = Basis(x_axis, y_axis, z_axis)
	global_transform.basis = new_basis
