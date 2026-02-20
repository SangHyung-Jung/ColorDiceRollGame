class_name ColoredDice
extends Dice

enum DiceColor {
	WHITE,
	BLACK,
	RED,
	BLUE,
	GREEN
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

# [추가] 주사위 타입별 모델 경로 반환 함수
func get_model_path(type_index: int, color: DiceColor) -> String:
	var color_name = COLOR_NAMES[color]
	
	match type_index:
		0: return "res://assets/models/0_dice_" + color_name + ".gltf"
		1: return "res://assets/models/1_plus_dice_" + color_name + ".gltf"
		2: return "res://assets/models/2_dollar_dice_" + color_name + ".gltf"
		3: return "res://assets/models/3_multiply_dice_" + color_name + ".gltf"
		4: return "res://assets/models/4_faceless_dice_" + color_name + ".gltf"
		5: return "res://assets/models/5_lucky_dice_777_red.gltf" # [수정] 항상 레드 모델만 사용
		6: return "res://assets/models/6_growing_dice_" + color_name + ".gltf"
		7: return "res://assets/models/7_ugly_dice_" + color_name + ".gltf"
		8: return "res://assets/models/8_dice_prism.tscn"
		_: return "res://assets/models/0_dice_" + color_name + ".gltf"

var current_dice_color: DiceColor = DiceColor.WHITE
var current_dice_type: int = 0

func _init() -> void:
	super()
	set_scene_file_path("")
	set_meta("_edit_lock_", true)
	set_meta("_edit_group_", false)

func setup_dice(color: DiceColor, position_override: Vector3 = Vector3.ZERO, type_index: int = 0) -> void:
	current_dice_color = color
	current_dice_type = type_index
	dice_color = COLOR_VALUES[color]
	
	if position_override != Vector3.ZERO:
		global_position = position_override
		original_position = position_override
	
	for child in get_children():
		if not child is OmniLight3D: # 조명은 유지 (필요시)
			child.queue_free()
	
	var model_path = get_model_path(type_index, color)
	if not ResourceLoader.exists(model_path):
		print("Warning: Model not found at ", model_path, ". Falling back to type 0.")
		model_path = get_model_path(0, color)
		
	var dice_scene = load(model_path)
	var dice_model = dice_scene.instantiate()
	add_child(dice_model)
	
	# 각 주사위 인스턴스가 고유한 재질을 갖도록 처리
	var mesh = _find_mesh_recursive(dice_model)
	if mesh:
		for i in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_active_material(i)
			if mat:
				mesh.set_surface_override_material(i, mat.duplicate())
	
	dice_model.owner = null
	dice_model.scene_file_path = ""
	
	var model_scale = 1.0
	dice_model.scale = Vector3(model_scale, model_scale, model_scale)
	dice_model.position = Vector3.ZERO
	dice_model.rotation_degrees = Vector3.ZERO
	
	# 충돌 박스 설정
	collider = CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	add_child(collider)
	
	var box_shape = BoxShape3D.new()
	var blender_dice_size = 2.0
	var actual_visual_size = blender_dice_size * model_scale
	var collision_margin = 0.95
	var collision_box_size = actual_visual_size * collision_margin
	
	box_shape.size = Vector3(collision_box_size, collision_box_size, collision_box_size)
	collider.shape = box_shape
	
	dice_name = COLOR_NAMES[color] + "_type" + str(type_index) + "_dice_" + str(randi())
	name = dice_name
	
	# 파티클이 있다면 활성화
	_activate_particles(dice_model)

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
