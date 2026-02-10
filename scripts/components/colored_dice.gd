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
	DiceColor.WHITE: preload("res://assets/models/9_dice_shadow_white.tscn"),
	DiceColor.BLACK: preload("res://assets/models/9_dice_shadow_black.tscn"),
	#DiceColor.RED: preload("res://assets/models/9_dice_shadow_red.tscn"),
	#DiceColor.BLUE: preload("res://assets/models/9_dice_shadow_blue.tscn"),
	#DiceColor.GREEN: preload("res://assets/models/9_dice_shadow_green.tscn")

	#DiceColor.WHITE: preload("res://assets/models/0_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/0_dice_black.gltf"),
	DiceColor.RED: preload("res://assets/models/0_dice_red.gltf"),
	DiceColor.BLUE: preload("res://assets/models/0_dice_blue.gltf"),
	DiceColor.GREEN: preload("res://assets/models/0_dice_green.gltf")

	#DiceColor.WHITE: preload("res://assets/models/glass_prism_dice.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/glass_prism_dice.gltf"),
	#DiceColor.RED: preload("res://assets/models/glass_prism_dice.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/glass_prism_dice.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/glass_prism_dice.gltf"),

	#DiceColor.WHITE: preload("res://assets/models/4_growing_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/4_growing_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/4_growing_dice_red.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/4_growing_dice_blue.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/4_growing_dice_green.gltf")
	#DiceColor.WHITE: preload("res://assets/models/0_dice_cracked_white.glb"),
	#DiceColor.BLACK: preload("res://assets/models/0_dice_cracked_black.glb"),
	#DiceColor.RED: preload("res://assets/models/0_dice_cracked_red.glb"),
	#DiceColor.BLUE: preload("res://assets/models/0_dice_cracked_blue.glb"),
	#DiceColor.GREEN: preload("res://assets/models/0_dice_cracked_green.glb")

	#DiceColor.WHITE: preload("res://assets/models/1_plus_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/1_plus_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/1_plus_dice_red.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/1_plus_dice_blue.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/1_plus_dice_green.gltf")	

	#DiceColor.WHITE: preload("res://assets/models/2_gold_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/2_gold_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/2_gold_dice_red.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/2_gold_dice_blue.gltf")
	#DiceColor.GREEN: preload("res://assets/models/2_gold_dice_green.gltf")

	#DiceColor.WHITE: preload("res://assets/models/3_multiply_dice_white.gltf"),
	#DiceColor.BLACK: preload("res://assets/models/3_multiply_dice_black.gltf"),
	#DiceColor.RED: preload("res://assets/models/3_multiply_dice_red.gltf"),
	#DiceColor.BLUE: preload("res://assets/models/3_multiply_dice_blue.gltf"),
	#DiceColor.GREEN: preload("res://assets/models/3_multiply_dice_green.gltf")

	#DiceColor.WHITE: preload("res://assets/models/4_faceless_dice_white.gltf"),
	#DiceColor.WHITE: preload("res://assets/models/0_dice_energy_black.gltf"),
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

# [추가] 조커 텍스처를 입히는 함수
func set_joker_texture(texture_path: String) -> void:
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		print("Invalid joker texture path: ", texture_path)
		return

	var joker_texture = load(texture_path)
	var mesh = get_mesh() # 부모 클래스인 Dice 혹은 ColoredDice의 헬퍼 함수 활용

	if mesh:
		# 기존 재질을 복제하거나 새 재질 생성
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = joker_texture

		# 조커 이미지가 주사위 전면에 잘 보이도록 UV 매핑 방식 조정 (필요 시)
		# 일반적인 박스 매핑 사용
		mat.uv1_triplanar = true 

		# 0번 서피스(주사위 몸체)에 재질 적용
		mesh.set_surface_override_material(0, mat)

		# 조커 주사위는 보통 흰색 베이스가 깔끔하므로 초기화
		dice_color = Color.WHITE

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
	
	# ==========================================
	# ★ TSCN/GLTF 둘 다 대응
	# ==========================================
	var dice_scene = DICE_GLTF_SCENES[color]
	var dice_model = dice_scene.instantiate()
	
	# TSCN인지 GLTF인지 자동 감지
	var is_tscn = _is_tscn_structure(dice_model)
	
	# 메시가 있는 실제 노드 찾기
	var mesh_parent = dice_model
	if is_tscn:
		# TSCN 구조: DiceShadow* → D6_Dice_* → ...
		mesh_parent = _find_gltf_node_in_tscn(dice_model)
	# GLTF 구조: D6_Dice_* (루트가 바로 GLTF)
	
	# 각 주사위 인스턴스가 고유한 재질을 갖도록 처리
	var mesh = _find_mesh_recursive(mesh_parent)
	if mesh:
		var mat = mesh.get_active_material(0)
		if mat:
			mesh.set_surface_override_material(0, mat.duplicate())
	
	## 새 모델 추가
	add_child(dice_model)
	
	# 모델 관련 설정
	dice_model.owner = null
	dice_model.scene_file_path = ""
	dice_model.set_meta("_edit_lock_", true)
	
	# ★ 모델 스케일 (Blender 원본 2.0 → 게임 내 1.0)
	var model_scale = 1.0
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
	var actual_visual_size = blender_dice_size * model_scale  # 2.0 * 1.0 = 2.0
	
	# 충돌 박스: 시각적 크기의 95% (5% 마진)
	var collision_margin = 0.95
	var collision_box_size = actual_visual_size * collision_margin  # 2.0 * 0.95 = 1.9
	
	box_shape.size = Vector3(
		collision_box_size,
		collision_box_size,
		collision_box_size
	)
	collider.shape = box_shape
	
	# 이름 설정
	dice_name = COLOR_NAMES[color] + "_dice_" + str(randi())
	name = dice_name
	
	# ==========================================
	# ★ TSCN이면 파티클 활성화
	# ==========================================
	if is_tscn:
		_activate_particles(dice_model)
		print("✅ Shadow dice (TSCN) loaded: ", name)
	else:
		print("✅ Basic dice (GLTF) loaded: ", name)

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

func _is_tscn_structure(node: Node) -> bool:
	if node.name.begins_with("D6_Dice"):
		return false
	for child in node.get_children():
		if child.name.begins_with("D6_Dice"):
			return true
	return false

func _find_gltf_node_in_tscn(tscn_root: Node) -> Node:
	for child in tscn_root.get_children():
		if child.name.begins_with("D6_Dice"):
			return child
	push_warning("Could not find GLTF node in TSCN, using root")
	return tscn_root

func _activate_particles(node: Node) -> void:
	if node is GPUParticles3D:
		node.emitting = true
		print("  ✅ Particle activated: ", node.name)
	for child in node.get_children():
		_activate_particles(child)
