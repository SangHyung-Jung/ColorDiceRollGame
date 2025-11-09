class_name DiceSpawner
extends Node3D

signal dice_roll_finished(value: int, dice_name: String)

const DiceDef := preload("res://addons/dice_roller/dice_def.gd")
const DiceShape := preload("res://addons/dice_roller/dice_shape.gd")
const PIPS_TEXTURE = preload("res://addons/dice_roller/dice/d6_dice/dice_texture.png")

const DICE_SCENES = {
	"white": preload("res://assets/models/dice_white.gltf"),
	"black": preload("res://assets/models/dice_black.gltf"),
	"red": preload("res://assets/models/dice_red.gltf"),
	"blue": preload("res://assets/models/dice_blue.gltf"),
	"green": preload("res://assets/models/dice_green.gltf")
}

const BLENDER_DICE_SIZE = 2.0
const GODOT_DICE_SIZE = 1.2

var dice_set: Array[DiceDef] = []
var dice_nodes: Array[Node] = []
var cup_ref: Node3D

func initialize(cup: Node3D) -> void:
	cup_ref = cup

func _get_dice_scene_key(color: Color) -> String:
	if color.is_equal_approx(Color.WHITE):
		return "white"
	elif color.is_equal_approx(Color.BLACK):
		return "black"
	elif color.is_equal_approx(Color.RED):
		return "red"
	elif color.is_equal_approx(Color.BLUE):
		return "blue"
	elif color.is_equal_approx(Color.GREEN):
		return "green"
	else:
		return "white"

func reset_and_spawn_all_dice(new_dice_defs: Array[DiceDef]) -> void:
	print("=== 통합 주사위 리셋 시작 ===")
	print("재활용 주사위: ", dice_nodes.size())
	print("새 생성 주사위: ", new_dice_defs.size())

	# 1단계: 기존 주사위들을 컵 위로 이동
	for i in range(dice_nodes.size()):
		var d = dice_nodes[i]
		print("재활용 주사위 ", i, " (", d.name, ") 리셋")

		if "freeze" in d:
			d.freeze = false
		d.sleeping = false
		d.linear_velocity = Vector3.ZERO
		d.angular_velocity = Vector3.ZERO
		
		# ★ 수정: 스폰 범위를 안전하게 (-0.5, 0.5) 사용
		var spawn_pos = cup_ref.global_position + Vector3(
			randf_range(-0.5, 0.5),
			4.0,
			randf_range(-0.5, 0.5)
		)
		d.global_position = spawn_pos
		d.linear_velocity.y = 0.0
		
		# (회전력 제거됨)
		
		# ★★★★★
		# ★ 핵심 수정: 순차 스폰 (물리 폭발 방지)
		# ★ 1프레임 대기하여 이 주사위가 먼저 떨어지기 시작하도록 함
		# ★★★★★
		await get_tree().process_frame

	# 2단계: 새 주사위들 생성
	dice_set.append_array(new_dice_defs)
	for i in range(new_dice_defs.size()):
		var d_def = new_dice_defs[i]
		print("새 주사위 ", i, " 생성: ", d_def.name, " 색상: ", d_def.color)
		
		var scene_key = _get_dice_scene_key(d_def.color)
		var dice_scene = DICE_SCENES.get(scene_key)
		
		if not dice_scene:
			push_error("주사위 씬을 찾을 수 없음: ", scene_key)
			continue
		
		var dice_instance = dice_scene.instantiate()
		var dice: Dice = _create_dice_from_gltf(dice_instance, d_def)
		
		var main_node = get_tree().current_scene
		if main_node == null:
			main_node = get_parent()
		main_node.add_child(dice)
		
		# ★ 수정: 스폰 범위를 안전하게 (-0.5, 0.5) 사용
		var spawn_pos = cup_ref.global_position + Vector3(
			randf_range(-0.5, 0.5),
			4.0,
			randf_range(-0.5, 0.5)
		)
		dice.global_position = spawn_pos
		
		print("주사위 위치: ", dice.global_position)
		print("컵 위치: ", cup_ref.global_position)
		
		dice.add_to_group('dice')
		dice.freeze = false
		dice.linear_velocity.y = 0.0

		# (회전력 제거됨)

		dice_nodes.append(dice)
		dice.roll_finished.connect(_on_dice_roll_finished.bind(dice.name))

		# ★★★★★
		# ★ 핵심 수정: 순차 스폰 (물리 폭발 방지)
		# ★ 1프레임 대기하여 이 주사위가 먼저 떨어지기 시작하도록 함
		# ★★★★★
		await get_tree().process_frame

	print("=== 모든 주사위 배치 완료 - 정착 대기 시작 ===")
	
	await wait_for_dice_settlement()
	
	print("=== 통합 주사위 리셋 완료 ===")

func _create_dice_from_gltf(gltf_instance: Node, d_def: DiceDef) -> Dice:
	var D6Dice = load("res://addons/dice_roller/dice/d6_dice/d6_dice.gd")
	
	var dice = D6Dice.new()
	dice.name = d_def.name
	dice.dice_color = d_def.color
	dice.pips_texture_original = d_def.pips_texture
	
	var collider = CollisionShape3D.new()
	collider.name = "Collider"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(GODOT_DICE_SIZE, GODOT_DICE_SIZE, GODOT_DICE_SIZE)
	box_shape.margin = 0.04
	collider.shape = box_shape
	dice.add_child(collider)
	
	var highlight = MeshInstance3D.new()
	highlight.name = "FaceHighligth"
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(GODOT_DICE_SIZE * 1.1, GODOT_DICE_SIZE * 1.1)
	quad_mesh.center_offset = Vector3(0, 0, -GODOT_DICE_SIZE * 0.4)
	highlight.mesh = quad_mesh
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	dice.add_child(highlight)
	
	gltf_instance.name = "DiceMesh"
	var scale_factor = GODOT_DICE_SIZE / BLENDER_DICE_SIZE
	gltf_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
	dice.add_child(gltf_instance)
	
	return dice

func _on_dice_roll_finished(value: int, dice_name: String) -> void:
	dice_roll_finished.emit(value, dice_name)

# ... (create_dice_definitions, create_new_dice_definitions 등 나머지 함수 동일) ...

func create_dice_definitions(bag: DiceBag, count: int) -> Array[DiceDef]:
	var defs: Array[DiceDef] = []
	if not bag.can_draw(count):
		push_error("Bag empty, cannot create dice definitions")
		return defs

	var d6_shape = DiceShape.new("D6")
	var keys = bag.draw_many(count)

	for i in range(count):
		var d_def = DiceDef.new()
		d_def.name = "D6_" + str(i)
		d_def.shape = d6_shape
		d_def.color = GameConstants.BAG_COLOR_MAP.get(keys[i], Color.WHITE)
		d_def.pips_texture = PIPS_TEXTURE
		defs.append(d_def)

	return defs

func create_new_dice_definitions(bag: DiceBag, count: int) -> Array[DiceDef]:
	var defs: Array[DiceDef] = []
	if not bag.can_draw(count):
		return defs

	var d6_shape = DiceShape.new("D6")
	var keys = bag.draw_many(count)

	for i in range(count):
		var d_def = DiceDef.new()
		d_def.name = "D6_new_%s_%d" % [str(Time.get_ticks_msec()), i]
		d_def.shape = d6_shape
		d_def.color = GameConstants.BAG_COLOR_MAP.get(keys[i], Color.WHITE)
		d_def.pips_texture = PIPS_TEXTURE
		defs.append(d_def)

	return defs

func tag_spawned_nodes_with_keys(keys: Array) -> void:
	var n: int = min(dice_nodes.size(), keys.size())
	for i in range(n):
		var d = dice_nodes[i]
		d.set_meta("bag_key", keys[i])

func apply_dice_impulse() -> void:
	for dice in dice_nodes:
		dice.apply_central_impulse(Vector3(
			randf_range(GameConstants.DICE_IMPULSE_RANGE.x, GameConstants.DICE_IMPULSE_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Y_RANGE.x, GameConstants.DICE_IMPULSE_Y_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Z_RANGE.x, GameConstants.DICE_IMPULSE_Z_RANGE.y)
		))

		dice.apply_torque_impulse(Vector3(
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y)
		))

		dice.rolling = true

func display_dice_results(roll_results: Dictionary) -> void:
	var center_x = 0.0
	var start_x = center_x - (dice_nodes.size() - 1) * 1.5
	var move_duration = GameConstants.MOVE_DURATION

	for i in range(dice_nodes.size()):
		var dice = dice_nodes[i]
		var target_pos = Vector3(start_x + i * GameConstants.DICE_SPACING, GameConstants.DISPLAY_Y, 0.0)

		var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		dice.freeze = true
		
		tween.parallel().tween_property(dice, "global_position", target_pos, move_duration)

		await tween.finished
		
		if roll_results.has(dice.name):
			dice.show_face(roll_results[dice.name])
		else:
			printerr("No roll result found for dice: ", dice.name)

func remove_dice(dice_to_remove: Array) -> void:
	print("=== remove_dice 시작 ===")
	print("제거할 주사위 개수: ", dice_to_remove.size())
	print("제거 전 dice_nodes 크기: ", dice_nodes.size())

	for dice in dice_to_remove:
		if dice in dice_nodes:
			dice_nodes.erase(dice)

			for i in range(dice_set.size() - 1, -1, -1):
				if dice_set[i].name == dice.name:
					dice_set.remove_at(i)
					break

	print("제거 후 dice_nodes 크기: ", dice_nodes.size())
	print("제거 후 dice_set 크기: ", dice_set.size())
	print("=== remove_dice 완료 ===")

func get_dice_nodes() -> Array[Node]:
	return dice_nodes

func get_dice_count() -> int:
	return dice_nodes.size()

func clear_dice_set() -> void:
	print("=== clear_dice_set 시작 ===")
	print("초기화 전 dice_set 크기: ", dice_set.size())
	print("초기화 전 dice_nodes 크기: ", dice_nodes.size())

	dice_set.clear()

	print("초기화 후 dice_set 크기: ", dice_set.size())
	print("=== clear_dice_set 완료 ===")

func wait_for_dice_settlement() -> void:
	print("=== 주사위 정착 대기 시작 ===")
	print("대기 시간: ", GameConstants.DICE_SETTLEMENT_TIME, "초")
	
	await get_tree().create_timer(GameConstants.DICE_SETTLEMENT_TIME).timeout
	
	print("=== 주사위 정착 완료 ===")
