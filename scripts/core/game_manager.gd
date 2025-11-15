## 게임 상태와 로직을 총괄 관리하는 핵심 클래스
## 주사위 굴리기, 결과 추적, Keep 시스템, 컵 상호작용 등
## 게임의 전반적인 상태 변화를 관리합니다.
class_name GameManager
extends Node

# 주사위 굴리기가 완료되었을 때 발생
signal roll_finished()

# === 핵심 게임 데이터 ===
var bag: DiceBag  # 주사위 가방 (자원 관리)
var _finished_dice_count: int = 0  # 굴리기 완료된 주사위 개수
var _roll_results: Dictionary[String, int] = {}  # 주사위별 결과값 저장
var _roll_in_progress: bool = false  # 현재 굴리기 진행 중 여부
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
	cup_collision_mesh = cup.get_node("PhysicsBody/CollisionMesh")

	# 컵 내부 영역의 시그널 연결 (주사위 진입/이탈 감지)
	var cup_inside_area: Area3D = cup.get_node("PhysicsBody/InsideArea")
	cup_inside_area.body_entered.connect(_on_dice_entered_cup)
	cup_inside_area.body_exited.connect(_on_dice_exited_cup)

func start_roll() -> void:
	_reset_roll_state()
	_roll_in_progress = true

	if cup_collision_mesh:
		cup_collision_mesh.use_collision = true

func on_dice_roll_finished(value: int, dice_name: String) -> void:
	print(dice_name, " rolled a ", value)
	_finished_dice_count += 1
	_roll_results[dice_name] = value

	# 현재 굴리기 중인 주사위 개수와 비교하여 완료 확인
	if dice_in_cup_count > 0:
		check_if_all_dice_finished(dice_in_cup_count)

func check_if_all_dice_finished(total_dice_count: int) -> bool:
	if _finished_dice_count == total_dice_count:
		print("\n--- Roll Finished! ---")
		_roll_in_progress = false
		bag.debug_print()
		roll_finished.emit()
		return true
	return false



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

func _reset_roll_state() -> void:
	_finished_dice_count = 0
	_roll_results.clear()

func can_draw_dice(count: int) -> bool:
	return bag.can_draw(count)

func is_roll_in_progress() -> bool:
	return _roll_in_progress



func get_roll_results() -> Dictionary:
	return _roll_results

func end_challenge_due_to_empty_bag() -> void:
	_roll_in_progress = false
	print("⚠️ Dice bag is empty. Challenge ends.")

# Cup area signal handlers
func _on_dice_entered_cup(body: Node3D) -> void:
	if body.is_in_group("dice"):
		dice_in_cup_count += 1
		# 컵 안으로 들어오면 컵 내부 물리 적용
		if body.has_method("apply_inside_cup_physics"):
			body.apply_inside_cup_physics()

func _on_dice_exited_cup(body: Node3D) -> void:
	# ★ 수정: 컵에서 나갈 때는 '테이블 물리'를 적용해주는 것이 맞습니다.
	if body.is_in_group("dice"):
		dice_in_cup_count -= 1
		if body.has_method("apply_outside_cup_physics"):
			body.apply_outside_cup_physics() # <- 이것은 유지
			
		if dice_in_cup_count <= 0:
			if cup_collision_mesh:
				cup_collision_mesh.use_collision = false
				print("All dice exited cup, disabling collision mesh.")
