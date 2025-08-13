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

const dice_size := 2.0
const dice_density := 10.0
const ANGULAR_VELOCITY_THRESHOLD := 1.
const LINEAR_VELOCITY_THRESHOLD := 0.1 * dice_size
const mounted_elevation = 0.8 * dice_size
const face_angle := 90.0

func max_tilt():
	return cos(deg_to_rad(face_angle/float(sides.size())))

var rolling := false
var roll_time := 0.0

signal roll_finished(int)

func _init() -> void:
	continuous_cd = true
	can_sleep = true
	# 물리 속성 조정: 중력 감소, 반발력 증가, 마찰 감소
	gravity_scale = 5
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.absorbent = true
	physics_material_override.bounce = 0.3
	physics_material_override.friction = 0.5

@onready var collider : CollisionShape3D = $Collider
@onready var highlight_face : Node3D = $FaceHighligth
@onready var mesh = $DiceMesh

func _adjust_to_size():
	mass = dice_density * dice_size**3
	collider.shape.margin = dice_size * 0.1

func _ready():
	original_position = position
	_adjust_to_size()
	self.sleeping_state_changed.connect(_on_sleeping_state_changed)
	
	call_deferred("_update_visuals")
	
	stop()
	
	self.angular_damp = 0.5

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
	sleeping = true
	position = original_position
	position.y = 5 * dice_size
	rotation = randf_range(0, 2*PI)*Vector3(1.,1.,1.)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func roll():
	"""Roll the dice"""
	if position.y < dice_size*2: stop()
	dehighlight()
	linear_velocity = Vector3(-dice_size, 0, -dice_size)
	angular_velocity = Vector3.ZERO
	freeze = false
	sleeping = false
	lock_rotation = false
	roll_time = 0
	rolling = true
	var torque_strength = mass * 4.0
	apply_torque_impulse( torque_strength * Vector3(
		randf_range(-1.,+1.),
		randf_range(-1.,+1.),
		randf_range(-1.,+1.)
	))

func shake(reason: String):
	"""Move a bad rolled dice"""
	apply_impulse(
		mass * 10. * Vector3(0,1,0),
		dice_size * Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)),
	)

func _process(_delta):
	if not rolling: return
	roll_time += _delta

# ★★ 수정된 부분: 주사위가 멈추는 방식을 변경합니다. ★★
func _on_sleeping_state_changed():
	if not rolling or not self.sleeping:
		return

	# 주사위가 다른 곳에 걸치거나 기울어져도 다시 굴리지 않고,
	# 현재 상태에서 가장 위에 있는 면을 결과로 즉시 사용하도록 수정합니다.
	var side = upper_side()

	print("Dice %s solved by sleeping [%s] - %.02fs"%([name, side, roll_time]))
	freeze = true

	# 빙글 도는 애니메이션(show_face) 대신, 즉시 결과를 하이라이트하고 신호를 보냅니다.
	highlight()
	roll_finished.emit(side)

# ★★ 수정된 부분: 가장 위에 있는 면을 찾는 방식을 변경합니다. ★★
func upper_side():
	"Returns which dice side is up, or 0 when none is clear"
	var highest_y := -INF
	var highest_side := 0
	for side in sides:
		var y = to_global(sides[side]).y
		if y < highest_y: continue
		highest_y = y
		highest_side = side
	
	# 기울어진 상태도 허용하기 위해, 각도를 확인하는 로직을 제거합니다.
	# if highest_y - global_position.y < max_tilt():
	# 	return null
		
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
	var side = upper_side()
	var side_orientation: Vector3 = sides[side].normalized()
	var perpendicular_side = side-1 if side-1 else len(sides)
	var perpendicular_direction = to_global(highlight_orientation[side]) - to_global(Vector3.ZERO)
	highlight_face.look_at(to_global(sides[side]), perpendicular_direction)
	highlight_face.visible = true

func dehighlight() -> void:
	highlight_face.visible = false
