## 게임 상태와 로직을 총괄 관리하는 핵심 클래스
## 주사위 굴리기, 결과 추적, Keep 시스템, 컵 상호작용 등
## 게임의 전반적인 상태 변화를 관리합니다.
class_name GameManager
extends Node

# 주사위 굴리기가 완료되었을 때 발생
signal roll_finished()
# 주사위가 Keep 영역으로 이동되었을 때 발생
signal dice_kept(dice: Node3D)
signal hand_dice_updated(dice_data: Array)
signal field_dice_updated(dice_data: Array)
signal dice_removed_for_combo(dice_nodes: Array[Node3D])

# === 핵심 게임 데이터 ===
var bag: DiceBag  # 주사위 가방 (자원 관리)
var hand_dice: Array[Node3D] = [] # Dice currently in the player's hand
var field_dice: Array[Node3D] = [] # Dice moved to the field
var _finished_dice_count: int = 0  # 굴리기 완료된 주사위 개수
var _roll_results: Dictionary[String, int] = {}  # 주사위별 결과값 저장
var _roll_in_progress: bool = false  # 현재 굴리기 진행 중 여부
var _selection_enabled: bool = false  # 주사위 선택 가능 여부
var kept_dice: Array[Node3D] = []  # 보관된 주사위들

# === 컵 시스템 관련 ===
var cup: Node3D  # 주사위 컵 참조
var cup_collision_mesh: Node3D  # 컵 충돌 메시
var dice_in_cup_count: int = 0  # 컵 안에 있는 주사위 개수

## 게임 매니저를 초기화합니다
## 주사위 가방을 생성하고 풀 세트로 설정합니다
func initialize() -> void:
	bag = DiceBag.new()
	bag.setup_full()  # 각 색상 8개씩 총 40개로 시작

## 컵 시스템을 설정하고 시그널을 연결합니다
## @param cup_node: 설정할 컵 노드
func setup_cup(cup_node: Node3D) -> void:
	cup = cup_node
	cup_collision_mesh = cup.get_node("CollisionMesh")

	# 컵 내부 영역의 시그널 연결 (주사위 진입/이탈 감지)
	var cup_inside_area: Area3D = cup.get_node("PhysicsBody/InsideArea")
	cup_inside_area.body_entered.connect(_on_dice_entered_cup)
	cup_inside_area.body_exited.connect(_on_dice_exited_cup)

func start_roll() -> void:
	_reset_roll_state()
	_roll_in_progress = true
	_selection_enabled = false

	# 컵 상태 리셋
	cup.reset()
	if cup_collision_mesh:
		cup_collision_mesh.use_collision = true

func on_dice_roll_finished(value: int, dice_name: String) -> void:
	print(dice_name, " rolled a ", value)
	_finished_dice_count += 1
	_roll_results[dice_name] = value

func check_if_all_dice_finished(total_dice_count: int) -> bool:
	if _finished_dice_count == total_dice_count:
		print("\n--- Roll Finished! ---")
		_roll_in_progress = false
		_selection_enabled = true
		bag.debug_print()
		roll_finished.emit()
		return true
	return false

func keep_dice(dice: Node3D) -> void:
	if kept_dice.has(dice):
		return

	# Keep 영역 배치
	var idx := kept_dice.size()
	var col := idx % GameConstants.KEEP_COLS
	var row := int(idx / GameConstants.KEEP_COLS)
	var target := GameConstants.KEEP_ANCHOR + Vector3(
		col * GameConstants.KEEP_STEP_X,
		0,
		row * GameConstants.KEEP_STEP_Z
	)

	# 물리 정지
	if "freeze" in dice:
		dice.freeze = false
	if "linear_velocity" in dice:
		dice.linear_velocity = Vector3.ZERO
	if "angular_velocity" in dice:
		dice.angular_velocity = Vector3.ZERO

	# 부드럽게 이동
	var tween: Tween = dice.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(dice, "global_position", target, GameConstants.KEEP_MOVE_DURATION)
	await tween.finished

	if "freeze" in dice:
		dice.freeze = true

	kept_dice.append(dice)

	# 결과 출력
	var val: int = int(_roll_results.get(dice.name, -1))
	print("[KEEP] ", dice.name, " -> value=", val)

	dice_kept.emit(dice)

func remove_combo_dice(nodes: Array) -> void:
	for n in nodes:
		if n == null or not is_instance_valid(n):
			continue

		# 결과 캐시 정리
		if _roll_results.has(n.name):
			_roll_results.erase(n.name)

		# 축소 애니메이션 후 삭제
		var tween: Tween = n.create_tween()
		tween.tween_property(n, "scale", n.scale * 0.01, 0.18)
		tween.tween_callback(Callable(n, "queue_free"))

	dice_removed_for_combo.emit(nodes)

func move_dice_to_field(dice_to_move: Array[Node3D]) -> void:
	for dice in dice_to_move:
		if hand_dice.has(dice):
			hand_dice.erase(dice)
			field_dice.append(dice)
			# TODO: Animate dice movement from hand area to field area

	hand_dice_updated.emit(_get_dice_display_data(hand_dice))
	field_dice_updated.emit(_get_dice_display_data(field_dice))

func _reset_roll_state() -> void:
	_finished_dice_count = 0
	_roll_results.clear()

func can_draw_dice(count: int) -> bool:
	return bag.can_draw(count)

func is_roll_in_progress() -> bool:
	return _roll_in_progress

func is_selection_enabled() -> bool:
	return _selection_enabled

func get_roll_results() -> Dictionary:
	return _roll_results

func end_challenge_due_to_empty_bag() -> void:
	_roll_in_progress = false
	_selection_enabled = false
	print("⚠️ Dice bag is empty. Challenge ends.")

# Cup area signal handlers
func _on_dice_entered_cup(body: Node3D) -> void:
	if body.has_method("apply_inside_cup_physics"):
		dice_in_cup_count += 1

func _on_dice_exited_cup(body: Node3D) -> void:
	if body.has_method("apply_outside_cup_physics"):
		dice_in_cup_count -= 1
		if dice_in_cup_count <= 0:
			if cup_collision_mesh:
				cup_collision_mesh.use_collision = false
				print("All dice exited cup, disabling collision mesh.")

func _get_dice_display_data(dice_nodes: Array[Node3D]) -> Array:
	var display_data: Array = []
	for dice in dice_nodes:
		if dice and is_instance_valid(dice):
			var color_name = ""
			if dice.has_method("get_dice_color"): # Assuming Dice class has this method
				var color = dice.get_dice_color()
				if color == Color.WHITE: color_name = "W"
				elif color == Color.BLACK: color_name = "K"
				elif color == Color.RED: color_name = "R"
				elif color == Color.GREEN: color_name = "G"
				elif color == Color.BLUE: color_name = "B"
				else: color_name = color.to_html(false)
			
			var value = _roll_results.get(dice.name, -1) # Get value from roll results
			var sides = 6 # Default, assuming D6 for now
			if dice.has_method("get_sides"): # Assuming Dice class has this method
				sides = dice.get_sides()

			display_data.append({
				"color": dice.get_dice_color() if dice.has_method("get_dice_color") else Color.WHITE,
				"value": value,
				"sides": sides
			})
		else:
			display_data.append("Invalid Dice") # Fallback for invalid instances
	return display_data

func highlight_dice(dice_nodes: Array[Node3D], highlight: bool) -> void:
	for dice in dice_nodes:
		if dice and is_instance_valid(dice) and dice.has_method("highlight"):
			dice.highlight(highlight)

func set_dice_fixed(dice: Node3D, fixed: bool) -> void:
	if dice and is_instance_valid(dice):
		dice.set_meta("fixed", fixed)
		if dice.has_method("set_fixed_visual"):
			dice.set_fixed_visual(fixed)

func get_usable_dice(dice_array: Array[Node3D]) -> Array[Node3D]:
	var usable_dice: Array[Node3D] = []
	for dice in dice_array:
		if dice and is_instance_valid(dice) and not dice.get_meta("fixed", false):
			usable_dice.append(dice)
	return usable_dice
