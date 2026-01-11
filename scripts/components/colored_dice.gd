class_name ColoredDice
extends Dice

enum DiceColor {
	WHITE,
	BLACK,
	RED,
	BLUE,
	GREEN
}

const DICE_GLTF_SCENES = {
	DiceColor.WHITE: preload("res://assets/models/0_dice_white.gltf"),
	DiceColor.BLACK: preload("res://assets/models/0_dice_black.gltf"),
	DiceColor.RED: preload("res://assets/models/0_dice_red.gltf"),
	DiceColor.BLUE: preload("res://assets/models/0_dice_blue.gltf"),
	DiceColor.GREEN: preload("res://assets/models/0_dice_green.gltf")

	#DiceColor.WHITE: preload("res://assets/models/1_plus_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/1_plus_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/1_plus_dice_red.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/1_plus_dice_blue.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/1_plus_dice_green.gltf")	

	#DiceColor.WHITE: preload("res://assets/models/2_gold_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/2_gold_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/2_gold_dice_red.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/2_gold_dice_blue.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/2_gold_dice_green.gltf")

	#DiceColor.WHITE: preload("res://assets/models/3_multiply_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/3_multiply_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/3_multiply_dice_red.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/3_multiply_dice_blue.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/3_multiply_dice_green.gltf")

	#DiceColor.WHITE: preload("res://assets/models/4_faceless_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/4_faceless_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/5_lucky_dice_777.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/5_lucky_dice_777.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/5_lucky_dice_777.gltf")	

}

const COLOR_VALUES = {
	DiceColor.WHITE: Color.WHITE,
	DiceColor.BLACK: Color.BLACK,
	DiceColor.RED: Color.RED,
	DiceColor.BLUE: Color.BLUE,
	DiceColor.GREEN: Color.GREEN
}

const COLOR_NAMES = {
	DiceColor.WHITE: "white",
	DiceColor.BLACK: "black",
	DiceColor.RED: "red",
	DiceColor.BLUE: "blue",
	DiceColor.GREEN: "green"
}

var current_dice_color: DiceColor = DiceColor.WHITE

func _init() -> void:
	super()
	# 동적 생성된 노드임을 표시하여 씬 저장 시 제외
	set_scene_file_path("")

	# 더 강력한 씬 저장 방지
	set_meta("_edit_lock_", true)
	set_meta("_edit_group_", false)

func setup_dice(color: DiceColor, position_override: Vector3 = Vector3.ZERO) -> void:
	current_dice_color = color
	dice_color = COLOR_VALUES[color]

	# 위치 먼저 설정
	if position_override != Vector3.ZERO:
		global_position = position_override
		original_position = position_override

	# 기존의 모든 자식 노드(메시, 콜라이더 등)를 제거하여 깨끗한 상태에서 시작
	for child in get_children():
		child.queue_free()

	# GLTF 모델 로드 및 설정
	var gltf_scene = DICE_GLTF_SCENES[color]
	var dice_model = gltf_scene.instantiate()

	# 각 주사위 인스턴스가 고유한 재질을 갖도록 처리
	var mesh = _find_mesh_recursive(dice_model)
	if mesh:
		var mat = mesh.get_active_material(0)
		if mat:
			mesh.set_surface_override_material(0, mat.duplicate())
	
	# 새 모델 추가
	add_child(dice_model)
	
	# 모델 관련 설정
	dice_model.owner = null
	dice_model.scene_file_path = ""
	dice_model.set_meta("_edit_lock_", true)

	# ★ 모델 스케일 (Blender 원본 2.0 → 게임 내 1.6)
	var model_scale = 0.8
	dice_model.scale = Vector3(model_scale, model_scale, model_scale)
	dice_model.position = Vector3.ZERO
	dice_model.rotation_degrees = Vector3.ZERO

	# 충돌 박스 설정
	collider = CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	add_child(collider)
	collider.owner = self # 이 노드가 소유하도록 설정
	
	var box_shape = BoxShape3D.new()
	
	# Blender 원본 크기
	var blender_dice_size = 2.0
	
	# 게임 내 실제 시각적 크기
	var actual_visual_size = blender_dice_size * model_scale  # 2.0 * 0.8 = 1.6
	
	# 충돌 박스: 시각적 크기의 95% (5% 마진)
	var collision_margin = 0.95
	var collision_box_size = actual_visual_size * collision_margin  # 1.6 * 0.95 = 1.52
	
	box_shape.size = Vector3(
		collision_box_size,
		collision_box_size,
		collision_box_size
	)
	collider.shape = box_shape

	# 이름 설정
	
	dice_name = COLOR_NAMES[color] + "_dice_" + str(randi())
	name = dice_name

func get_dice_color_name() -> String:
	return COLOR_NAMES[current_dice_color]

func get_dice_color_value() -> Color:
	return COLOR_VALUES[current_dice_color]

static func color_from_string(color_name: String) -> DiceColor:
	match color_name.to_lower():
		"white": return DiceColor.WHITE
		"black": return DiceColor.BLACK
		"red": return DiceColor.RED
		"blue": return DiceColor.BLUE
		"green": return DiceColor.GREEN
		_: return DiceColor.WHITE

static func color_from_godot_color(color: Color) -> DiceColor:
	if color.is_equal_approx(Color.WHITE):
		return DiceColor.WHITE
	elif color.is_equal_approx(Color.BLACK):
		return DiceColor.BLACK
	elif color.is_equal_approx(Color.RED):
		return DiceColor.RED
	elif color.is_equal_approx(Color.BLUE):
		return DiceColor.BLUE
	elif color.is_equal_approx(Color.GREEN):
		return DiceColor.GREEN
	else:
		return DiceColor.WHITE

# 메시 노드를 재귀적으로 찾아서 반환하는 공용 함수
func get_mesh() -> MeshInstance3D:
	return _find_mesh_recursive(self)

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	# Check if the node itself is a MeshInstance3D
	if node is MeshInstance3D:
		return node
	# Otherwise, check its children
	for child in node.get_children():
		var mesh = _find_mesh_recursive(child)
		if mesh:
			return mesh
	return null
