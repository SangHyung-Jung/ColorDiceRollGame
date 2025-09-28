## 주사위 생성, 배치, 관리를 담당하는 컴포넌트
## 주사위 정의에서 실제 3D 주사위 노드 생성, 물리 설정,
## 결과 표시, 위치 재배치 등의 주사위 라이프사이클을 관리합니다.
class_name DiceSpawner
extends Node3D

# 개별 주사위의 굴리기 완료 시그널
signal dice_roll_finished(value: int, dice_name: String)

# === 주사위 애드온 리소스 ===
const DiceDef := preload("res://addons/dice_roller/dice_def.gd")  # 주사위 정의 클래스
const DiceShape := preload("res://addons/dice_roller/dice_shape.gd")  # 주사위 모양 클래스
const PIPS_TEXTURE = preload("res://addons/dice_roller/dice/d6_dice/dice_texture.png")  # 주사위 눈 텍스처

# === 내부 데이터 ===
var dice_set: Array[DiceDef] = []  # 주사위 정의 배열
var dice_nodes: Array[Node] = []   # 실제 생성된 주사위 노드들
var cup_ref: Node3D                # 컵 참조 (생성 위치 계산용)

## 주사위 스폰너 초기화
## @param cup: 주사위를 생성할 컵의 참조
func initialize(cup: Node3D) -> void:
	cup_ref = cup

## 주사위들을 컵 내부에 생성합니다
## @param dice_definitions: 생성할 주사위들의 정의 배열
func spawn_dice_in_cup(dice_definitions: Array[DiceDef]) -> void:
	print("=== spawn_dice_in_cup 시작 ===")
	print("새로 생성할 주사위 개수: ", dice_definitions.size())
	print("기존 주사위 개수: ", dice_nodes.size())

	# 컵 위치 정보 출력 (비교용)
	if cup_ref:
		print("컵 위치 (생성 시): ", cup_ref.global_position)

	# ★ 수정: 기존 dice_set에 추가 (덮어쓰기 방지)
	dice_set.append_array(dice_definitions)
	
	# 각 주사위 정의에 따라 3D 주사위 노드 생성
	for i in range(dice_definitions.size()):
		var d_def = dice_definitions[i]
		print("주사위 ", i, " 생성 시작: ", d_def.name)
		
		# 애드온에서 주사위 씬 인스턴스 생성
		var dice_scene = d_def.shape.scene()
		var dice: Dice = dice_scene.instantiate()
		
		# 주사위 속성 설정
		dice.name = d_def.name
		dice.dice_color = d_def.color
		dice.pips_texture_original = d_def.pips_texture
		
		# 컵 내부 랜덤 위치에 생성
		var spawn_pos = cup_ref.global_position + Vector3(
			randf_range(-GameConstants.CUP_SPAWN_RADIUS, GameConstants.CUP_SPAWN_RADIUS),
			GameConstants.CUP_SPAWN_HEIGHT,
			randf_range(-GameConstants.CUP_SPAWN_RADIUS, GameConstants.CUP_SPAWN_RADIUS)
		)
		dice.global_position = spawn_pos
		print("주사위 생성 위치: ", spawn_pos)
		
		# ★ 해결책: 명확한 부모 노드 지정
		var main_node = get_tree().current_scene
		if main_node == null:
			main_node = get_parent()  # 폴백
		
		print("부모 노드: ", main_node.name)
		main_node.add_child(dice)
		
		dice.add_to_group('dice')  # 주사위 그룹에 추가 (선택용)
		dice.freeze = false  # 물리 활성화
		dice.linear_velocity.y = GameConstants.DICE_SPAWN_VELOCITY  # 초기 하향 속도

		# 컵 내부에서도 약간의 회전력 적용 (자연스러운 움직임)
		dice.apply_torque_impulse(Vector3(
			randf_range(GameConstants.DICE_TORQUE_RANGE.x * 0.3, GameConstants.DICE_TORQUE_RANGE.y * 0.3),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x * 0.3, GameConstants.DICE_TORQUE_RANGE.y * 0.3),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x * 0.3, GameConstants.DICE_TORQUE_RANGE.y * 0.3)
		))

		dice_nodes.append(dice)
		
		print("주사위 ", i, " 생성 완료. dice_nodes 크기: ", dice_nodes.size())
		
		# 굴리기 완료 시그널 연결
		dice.roll_finished.connect(_on_dice_roll_finished.bind(dice.name))
	
	print("=== spawn_dice_in_cup 완료 ===")
	print("총 주사위 개수: ", dice_nodes.size())

## 개별 주사위의 굴리기 완료 시그널 전달
## @param value: 주사위 결과값
## @param dice_name: 주사위 이름
func _on_dice_roll_finished(value: int, dice_name: String) -> void:
	dice_roll_finished.emit(value, dice_name)

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
		# 더 강한 중앙 힘 적용 (X, Y, Z축 모두)
		dice.apply_central_impulse(Vector3(
			randf_range(GameConstants.DICE_IMPULSE_RANGE.x, GameConstants.DICE_IMPULSE_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Y_RANGE.x, GameConstants.DICE_IMPULSE_Y_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Z_RANGE.x, GameConstants.DICE_IMPULSE_Z_RANGE.y)
		))

		# 회전력 추가로 더 많이 굴리게 함
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

		dice.freeze = false
		tween.parallel().tween_property(dice, "global_position", target_pos, move_duration)

		await tween.finished
		dice.show_face(roll_results[dice.name])

## 향상된 리셋 함수 - 정착 시간 포함
## 주사위를 컵 위에서 떨어뜨리고 정착까지 대기합니다
func reset_dice_in_cup_with_settlement() -> void:
	print("=== 주사위 리셋 시작 (정착 대기 포함) ===")
	print("현재 주사위 개수: ", dice_nodes.size())

	# 컵 위치 상세 디버깅
	print("컵 참조 존재: ", cup_ref != null)
	if cup_ref:
		print("컵 global_position: ", cup_ref.global_position)

	# 남아있는 주사위들을 컵 위에서 떨어뜨리기
	for i in range(dice_nodes.size()):
		var d = dice_nodes[i]
		print("주사위 ", i, " (", d.name, ") 리셋 시작")
		print("  기존 위치: ", d.global_position)

		# 물리 상태 초기화
		if "freeze" in d:
			d.freeze = false
		d.sleeping = false
		d.linear_velocity = Vector3.ZERO
		d.angular_velocity = Vector3.ZERO

		# 컵 위 높은 곳에 배치 (spawn_dice_in_cup과 동일한 로직)
		var spawn_pos = cup_ref.global_position + Vector3(
			randf_range(-GameConstants.CUP_SPAWN_RADIUS, GameConstants.CUP_SPAWN_RADIUS),
			GameConstants.CUP_SPAWN_HEIGHT,  # 새로 생성되는 주사위와 동일한 높이
			randf_range(-GameConstants.CUP_SPAWN_RADIUS, GameConstants.CUP_SPAWN_RADIUS)
		)
		d.global_position = spawn_pos
		print("  새 위치 (컵 위): ", d.global_position)

		# 새로 생성되는 주사위와 동일한 초기 속도 적용
		d.linear_velocity.y = GameConstants.DICE_SPAWN_VELOCITY  # 초기 하향 속도

		# 새로 생성되는 주사위와 동일한 회전력 적용
		d.apply_torque_impulse(Vector3(
			randf_range(GameConstants.DICE_TORQUE_RANGE.x * 0.3, GameConstants.DICE_TORQUE_RANGE.y * 0.3),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x * 0.3, GameConstants.DICE_TORQUE_RANGE.y * 0.3),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x * 0.3, GameConstants.DICE_TORQUE_RANGE.y * 0.3)
		))

	print("=== 주사위 리셋 완료 - 정착 대기 시작 ===")
	
	# 주사위들이 컵 바닥에 정착할 때까지 대기
	await wait_for_dice_settlement()


## 주사위들을 제거합니다 (Keep이나 조합 사용 시)
## @param dice_to_remove: 제거할 주사위 노드들
func remove_dice(dice_to_remove: Array) -> void:
	print("=== remove_dice 시작 ===")
	print("제거할 주사위 개수: ", dice_to_remove.size())
	print("제거 전 dice_nodes 크기: ", dice_nodes.size())

	for dice in dice_to_remove:
		if dice in dice_nodes:
			# dice_nodes에서 제거
			dice_nodes.erase(dice)

			# dice_set에서도 해당하는 정의 제거
			for i in range(dice_set.size() - 1, -1, -1):  # 역순으로 순회
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

## 주사위 세트를 완전히 초기화합니다 (새 게임 시작 등)
func clear_dice_set() -> void:
	print("=== clear_dice_set 시작 ===")
	print("초기화 전 dice_set 크기: ", dice_set.size())
	print("초기화 전 dice_nodes 크기: ", dice_nodes.size())

	dice_set.clear()
	# dice_nodes는 실제 노드 제거 시에만 정리됨

	print("초기화 후 dice_set 크기: ", dice_set.size())
	print("=== clear_dice_set 완료 ===")

## 주사위들이 컵 바닥에 정착할 때까지 대기하는 함수
## 리셋 후 흔들기를 시작하기 전에 호출되어야 합니다
func wait_for_dice_settlement() -> void:
	print("=== 주사위 정착 대기 시작 ===")
	print("대기 시간: ", GameConstants.DICE_SETTLEMENT_TIME, "초")
	
	# 정착 시간만큼 대기
	await get_tree().create_timer(GameConstants.DICE_SETTLEMENT_TIME).timeout
	
	print("=== 주사위 정착 완료 ===")
