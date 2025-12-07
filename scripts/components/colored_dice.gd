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
	DiceColor.WHITE: preload("res://assets/models/dice_white.gltf"),
	DiceColor.BLACK: preload("res://assets/models/dice_black.gltf"),
	DiceColor.RED: preload("res://assets/models/dice_red.gltf"),
	DiceColor.BLUE: preload("res://assets/models/dice_blue.gltf"),
	DiceColor.GREEN: preload("res://assets/models/dice_green.gltf")
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
		print("🎲 Setting dice position to: ", position_override)

	# GLTF 모델 로드 및 설정
	var gltf_scene = DICE_GLTF_SCENES[color]
	var dice_model = gltf_scene.instantiate()

	# 기존 MeshInstance3D가 있다면 제거
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()

	# 새 모델 추가
	add_child(dice_model)

	# 모델도 씬에 저장되지 않도록 보호
	dice_model.owner = null
	dice_model.scene_file_path = ""
	dice_model.set_meta("_edit_lock_", true)

	# 크기 조정 (더 잘 보이도록 크게 설정)
	dice_model.scale = Vector3(0.85, 0.85, 0.85)

	# 모델의 로컬 위치를 0으로 설정하여 부모(주사위)의 위치와 일치시킴
	dice_model.position = Vector3.ZERO

	# 모델의 기본 회전이 잘못되어 있을 경우를 대비한 초기 회전 설정
	# (필요시 조정)
	dice_model.rotation_degrees = Vector3.ZERO

	# 충돌 박스 설정
	collider = CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.owner = null
	collider.scene_file_path = ""
	collider.set_meta("_edit_lock_", true)
	add_child(collider)

	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(DICE_SIZE, DICE_SIZE, DICE_SIZE)
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
