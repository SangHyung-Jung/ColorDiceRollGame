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
	dice_set = dice_definitions

	# 각 주사위 정의에 따라 3D 주사위 노드 생성
	for d_def in dice_set:
		# 애드온에서 주사위 씩 인스턴스 생성
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

		# 씩에 추가 및 물리 설정
		get_parent().add_child(dice)
		dice.add_to_group('dice')  # 주사위 그룹에 추가 (선택용)
		dice.freeze = false  # 물리 활성화
		dice.linear_velocity.y = GameConstants.DICE_SPAWN_VELOCITY  # 초기 하향 속도
		dice_nodes.append(dice)

		# 굴리기 완료 시그널 연결
		dice.roll_finished.connect(_on_dice_roll_finished.bind(dice.name))

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
		dice.apply_central_impulse(Vector3(
			randf_range(GameConstants.DICE_IMPULSE_RANGE.x, GameConstants.DICE_IMPULSE_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Y_RANGE.x, GameConstants.DICE_IMPULSE_Y_RANGE.y),
			0
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

func reset_dice_in_cup() -> void:
	# 컵 내부 치수 결정
	var r: float = 2.8
	var h: float = 6.0
	var col: CollisionShape3D = cup_ref.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is CylinderShape3D:
		var cyl := col.shape as CylinderShape3D
		r = cyl.radius
		h = cyl.height

	# 남아있는 주사위들을 컵 안으로 재배치
	for d in dice_nodes:
		if "freeze" in d:
			d.freeze = false
		d.sleeping = false
		d.linear_velocity = Vector3.ZERO
		d.angular_velocity = Vector3.ZERO

		var theta: float = randf() * TAU
		var margin: float = 0.30
		var rr: float = max(0.0, r - margin) * sqrt(randf())
		var yy: float = -h * 0.5 + h * 0.70
		var local := Vector3(rr * cos(theta), yy, rr * sin(theta))
		d.global_position = cup_ref.to_global(local)

		# 살짝 깨워서 굴림 안정화
		d.apply_torque_impulse(Vector3(
			randf_range(-0.6, 0.6),
			randf_range(-0.2, 0.2),
			randf_range(-0.6, 0.6)
		))
		d.apply_central_impulse(Vector3(
			randf_range(-0.2, 0.2),
			0.0,
			randf_range(-0.2, 0.2)
		))

func remove_dice(dice_to_remove: Array) -> void:
	for dice in dice_to_remove:
		if dice in dice_nodes:
			dice_nodes.erase(dice)

func get_dice_nodes() -> Array[Node]:
	return dice_nodes

func get_dice_count() -> int:
	return dice_nodes.size()

func clear_dice_set() -> void:
	dice_set.clear()
