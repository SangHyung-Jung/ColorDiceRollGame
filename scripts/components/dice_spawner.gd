class_name DiceSpawner
extends Node3D

signal dice_roll_finished(value: int, dice_name: String)

const DICE_SIZE = 1.2

var dice_nodes: Array[ColoredDice] = []
var cup_ref: Node3D
var runtime_container: Node3D  # 동적 노드들을 넣을 컨테이너

func initialize(cup: Node3D, container: Node3D = null) -> void:
	cup_ref = cup
	runtime_container = container

func _get_dice_color_from_godot_color(color: Color) -> ColoredDice.DiceColor:
	return ColoredDice.color_from_godot_color(color)

func reset_and_spawn_all_dice(dice_colors: Array[Color]) -> void:
	print("=== 새로운 주사위 리셋 시작 ===")
	print("재활용 주사위: ", dice_nodes.size())
	print("새 생성 주사위: ", dice_colors.size())

	# 1단계: 기존 주사위들을 컵 위로 이동
	for i in range(dice_nodes.size()):
		var dice = dice_nodes[i]
		print("재활용 주사위 ", i, " (", dice.name, ") 리셋")

		# 시그널 중복 연결 방지 - 재활용 주사위는 이미 연결되어 있음
		# 따라서 여기서는 연결하지 않음

		dice.reset_position(cup_ref.global_position + Vector3(
			randf_range(-0.5, 0.5),
			4.0,
			randf_range(-0.5, 0.5)
		))

		# 재활용 주사위도 스폰 물리 적용
		dice.setup_physics_for_spawning()

		await get_tree().process_frame

	# 2단계: 새 주사위들 생성
	for i in range(dice_colors.size()):
		var color = dice_colors[i]
		print("새 주사위 ", i, " 생성, 색상: ", color)

		var dice_color = _get_dice_color_from_godot_color(color)
		var dice = ColoredDice.new()

		var target_parent = runtime_container
		if target_parent == null:
			target_parent = get_tree().current_scene
			if target_parent == null:
				target_parent = get_parent()
		target_parent.add_child(dice)

		# 동적 생성된 노드는 씬에 저장되지 않도록 설정
		dice.owner = null
		dice.set_meta("_editor_description_", "Runtime Generated Dice - Do Not Save")
		dice.set_meta("_edit_lock_", true)
		dice.add_to_group("runtime_dice", true)

		# 추가 보호: 씬 트리에서 완전히 분리
		dice.scene_file_path = ""

		var spawn_pos = cup_ref.global_position + Vector3(
			randf_range(-0.5, 0.5),
			4.0,
			randf_range(-0.5, 0.5)
		)

		dice.setup_dice(dice_color, spawn_pos)
		dice.setup_physics_for_spawning()

		dice_nodes.append(dice)

		# 중복 연결 방지
		if not dice.roll_finished.is_connected(_on_dice_roll_finished):
			dice.roll_finished.connect(_on_dice_roll_finished)

		await get_tree().process_frame

	print("=== 모든 주사위 배치 완료 - 정착 대기 시작 ===")

	await wait_for_dice_settlement()

	print("=== 주사위 리셋 완료 ===")


func _on_dice_roll_finished(value: int, dice_name: String) -> void:
	dice_roll_finished.emit(value, dice_name)

func create_dice_colors_from_bag(bag: DiceBag, count: int) -> Array[Color]:
	var colors: Array[Color] = []
	if not bag.can_draw(count):
		push_error("Bag empty, cannot create dice colors")
		return colors

	var keys = bag.draw_many(count)

	for key in keys:
		var color = GameConstants.BAG_COLOR_MAP.get(key, Color.WHITE)
		colors.append(color)

	return colors

func tag_spawned_nodes_with_keys(keys: Array) -> void:
	var n: int = min(dice_nodes.size(), keys.size())
	for i in range(n):
		var dice = dice_nodes[i]
		dice.set_meta("bag_key", keys[i])

func apply_dice_impulse() -> void:
	for dice in dice_nodes:
		var impulse = Vector3(
			randf_range(GameConstants.DICE_IMPULSE_RANGE.x, GameConstants.DICE_IMPULSE_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Y_RANGE.x, GameConstants.DICE_IMPULSE_Y_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Z_RANGE.x, GameConstants.DICE_IMPULSE_Z_RANGE.y)
		)

		var torque = Vector3(
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y)
		)

		dice.apply_impulse_force(impulse, torque)
		dice.start_rolling()

func display_dice_results(roll_results: Dictionary) -> void:
	var center_x = 0.0
	var start_x = center_x - (dice_nodes.size() - 1) * 1.5
	var move_duration = GameConstants.MOVE_DURATION

	for i in range(dice_nodes.size()):
		var dice = dice_nodes[i]

		# 결과값 먼저 확인
		if not roll_results.has(dice.name):
			printerr("No roll result found for dice: ", dice.name)
			continue

		var result_value = roll_results[dice.name]
		print("Dice ", dice.name, " rolled: ", result_value)

		# 주사위를 해당 면으로 회전 (물리 멈추기 전에 먼저 설정)
		dice.show_face(result_value)

		# 물리 정지
		dice.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO

		var target_pos = Vector3(start_x + i * GameConstants.DICE_SPACING, GameConstants.DISPLAY_Y, 0.0)
		var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# 위치만 이동 (회전은 유지)
		tween.parallel().tween_property(dice, "global_position", target_pos, move_duration)

		await tween.finished

func remove_dice(dice_to_remove: Array) -> void:
	print("=== remove_dice 시작 ===")
	print("제거할 주사위 개수: ", dice_to_remove.size())
	print("제거 전 dice_nodes 크기: ", dice_nodes.size())

	for dice in dice_to_remove:
		if dice in dice_nodes:
			dice_nodes.erase(dice)

	print("제거 후 dice_nodes 크기: ", dice_nodes.size())
	print("=== remove_dice 완료 ===")

func get_dice_nodes() -> Array[ColoredDice]:
	return dice_nodes

func get_dice_count() -> int:
	return dice_nodes.size()

func clear_dice_nodes() -> void:
	print("=== clear_dice_nodes 시작 ===")
	print("초기화 전 dice_nodes 크기: ", dice_nodes.size())

	dice_nodes.clear()

	print("초기화 후 dice_nodes 크기: ", dice_nodes.size())
	print("=== clear_dice_nodes 완료 ===")

func wait_for_dice_settlement() -> void:
	print("=== 주사위 정착 대기 시작 ===")
	print("대기 시간: ", GameConstants.DICE_SETTLEMENT_TIME, "초")
	
	await get_tree().create_timer(GameConstants.DICE_SETTLEMENT_TIME).timeout
	
	print("=== 주사위 정착 완료 ===")
