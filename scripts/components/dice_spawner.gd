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
	print("=== 새로운 주사위 스폰 시작 ===")
	print("생성할 주사위 수: ", dice_colors.size())

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

		dice.owner = null
		dice.set_meta("_editor_description_", "Runtime Generated Dice - Do Not Save")
		dice.set_meta("_edit_lock_", true)
		dice.add_to_group("runtime_dice", true)
		dice.scene_file_path = ""

		var spawn_pos = cup_ref.global_position + Vector3(
			randf_range(-0.3, 0.3),
			1.5,                        # Y=11.5, ceiling(12.7) 안쪽
			randf_range(-0.3, 0.3)
		)
		await get_tree().create_timer(0.1).timeout  # 0.25초 간격

		dice.setup_dice(dice_color, spawn_pos)
		dice.setup_physics_for_spawning()
		dice_nodes.append(dice)

		if not dice.roll_finished.is_connected(_on_dice_roll_finished):
			dice.roll_finished.connect(_on_dice_roll_finished)

		await get_tree().process_frame

	print("=== 모든 주사위 배치 완료 - 정착 대기 시작 ===")
	await wait_for_dice_settlement()
	print("=== 주사위 스폰 완료 ===")
	

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

		print("DiceSpawner: Applying impulse %s to dice %s" % [impulse, dice.name])
		dice.apply_impulse_force(impulse, torque)
		dice.start_rolling()

func display_dice_results(roll_results: Dictionary) -> void:
	var center_x = 0.0
	var start_x = center_x - (dice_nodes.size() - 1) * 1.5
	var move_duration = GameConstants.MOVE_DURATION
	
	# 단일 트윈으로 모든 주사위의 움직임을 병렬 처리하여 안정성 확보
	var master_tween: Tween = create_tween().set_parallel()
	master_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
		
		# ★ 핵심: 충돌 비활성화 (이동 중 다른 주사위와 충돌 방지)
		dice.collision_layer = 0
		dice.collision_mask = 0

		var target_pos = Vector3(start_x + i * GameConstants.DICE_SPACING, GameConstants.DISPLAY_Y, 0.0)
		
		# 마스터 트윈에 각 주사위의 위치 이동 애니메이션을 추가
		master_tween.tween_property(dice, "global_position", target_pos, move_duration)
		
		# [추가] 조명 위치도 주사위 위치에 맞춰 동기화
		_sync_result_light(i, target_pos)

	# ★ 모든 병렬 애니메이션이 완료될 때까지 한 번만 대기
	await master_tween.finished

func _sync_result_light(index: int, target_pos: Vector3) -> void:
	# runtime_container(3D_World)에서 RollingWorld를 찾아 조명 컨테이너 접근
	if not runtime_container: return
	var rolling_world = runtime_container.get_node_or_null("PlayArea#RollingWorld")
	if not rolling_world: return
	
	var lights_container = rolling_world.get_node_or_null("PinpointLights")
	if not lights_container: return
	
	if index < 5: # ResultLight는 0~4번
		var light = lights_container.get_child(index) as OmniLight3D
		if light:
			light.global_position = target_pos + Vector3(0, 3, 0)
	
	# ★ 모든 이동이 완료된 후 충돌 복원
	print("=== 주사위 정렬 완료, 충돌 복원 시작 ===")
	for dice in dice_nodes:
		if is_instance_valid(dice):
			dice.collision_layer = 1
			dice.collision_mask = 1
			print("  ", dice.name, " 충돌 복원 완료")
	print("=== 충돌 복원 완료 ===")

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

	# 최소 대기 (물리 엔진이 첫 처리를 할 시간 확보)
	await get_tree().create_timer(0.5).timeout

	# 실제 속도 기반 정착 확인
	var max_wait := 3.0
	var elapsed := 0.0
	var check_interval := 0.1

	while elapsed < max_wait:
		await get_tree().create_timer(check_interval).timeout
		elapsed += check_interval

		var all_settled := true
		for dice in dice_nodes:
			if is_instance_valid(dice):
				if dice.linear_velocity.length() > 0.05:
					all_settled = false
					break

		if all_settled:
			break

	print("=== 주사위 정착 완료 (경과: %.1f초) ===" % (0.5 + elapsed))
