extends RigidBody3D
class_name ShopDice

@onready var faces = [
	$Faces/Face1, $Faces/Face2, $Faces/Face3, 
	$Faces/Face4, $Faces/Face5, $Faces/Face6
]

# 각 면의 로컬 방향 벡터 (순서 중요: Face1~6 순서와 일치해야 함)
var face_vectors = [
	Vector3.UP, Vector3.DOWN, Vector3.FORWARD,
	Vector3.BACK, Vector3.RIGHT, Vector3.LEFT
]

var assigned_jokers = [] # 이 주사위에 할당된 6개의 조커 데이터

func _init() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	can_sleep = true # Shop dice CAN sleep
	gravity_scale = 10
	mass = 1.5
	
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


func setup_jokers(jokers_list: Array):
	assigned_jokers = jokers_list
	for i in range(6):
		if i >= jokers_list.size():
			print("Warning: Not enough jokers to assign to all 6 faces.")
			break
			
		var joker = jokers_list[i]
		var sprite = faces[i] as Sprite3D
		
		# english_name을 기반으로 텍스처 로드
		var texture_path = "res://assets/joker_images/" + joker["english_name"] + ".png"
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
		else:
			print("Warning: Texture not found at: ", texture_path)
		
		sprite.pixel_size = 0.005

# 굴림이 멈췄을 때 윗면의 조커 반환
func get_top_joker():
	var max_dot = -1.0
	var best_index = 0
	
	for i in range(6):
		var world_face_dir = global_transform.basis * face_vectors[i]
		var dot = world_face_dir.dot(Vector3.UP)
		if dot > max_dot:
			max_dot = dot
			best_index = i
			
	if best_index < assigned_jokers.size():
		return assigned_jokers[best_index]
	else:
		return null

# --- Physics Methods copied from Dice.gd ---

func setup_physics_for_spawning() -> void:
	gravity_scale = 40
	linear_damp = 0.1
	angular_damp = 0.1

	if physics_material_override:
		physics_material_override.friction = 0.5
		physics_material_override.bounce = 0.3

func apply_outside_cup_physics() -> void:
	gravity_scale = 20
	linear_damp = 0.7
	angular_damp = 0.7

	if physics_material_override:
		physics_material_override.friction = 0.8
		physics_material_override.bounce = 0.2

func apply_impulse_force(impulse: Vector3, torque: Vector3) -> void:
	apply_central_impulse(impulse)
	apply_torque_impulse(torque)
