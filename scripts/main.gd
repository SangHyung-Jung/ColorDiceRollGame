## ColorComboDice2 메인 컨트롤러
## 전체 게임의 최상위 조율자로서 모든 매니저와 컴포넌트를
## 초기화하고 연결하며, 게임 흐름을 총괄 관리합니다.
## 리팩토링을 통해 470줄에서 171줄로 축소되었습니다.
extends Node3D

# === 컴포넌트 및 매니저 참조들 ===
var scene_manager: SceneManager    # 3D 환경 설정 (카메라, 조명, 바닥)
var game_manager: GameManager      # 게임 상태 및 로직 관리
var input_manager: InputManager    # 입력 처리 및 이벤트 분배
var score_manager: ScoreManager    # 점수 계산 및 추적
var dice_spawner: DiceSpawner      # 주사위 생성 및 관리
var combo_select: ComboSelect      # 조합 선택 UI
var cup: Node3D                    # 주사위 컵 인스턴스

# === 리소스 로드 ===
const CupScene := preload("res://cup.tscn")  # 컵 씬 파일

## 게임 시작 시 초기화 순서
## 모든 매니저와 컴포넌트를 생성하고 설정한 후 시그널을 연결합니다
func _ready() -> void:
	_initialize_managers()  # 1단계: 모든 매니저 생성
	_setup_scene()         # 2단계: 3D 환경 및 컵 설정
	_setup_game()          # 3단계: 게임 로직 초기화
	_connect_signals()     # 4단계: 컴포넌트 간 시그널 연결

func _initialize_managers() -> void:
	# 매니저들 생성
	scene_manager = SceneManager.new()
	game_manager = GameManager.new()
	input_manager = InputManager.new()
	score_manager = ScoreManager.new()
	dice_spawner = DiceSpawner.new()
	combo_select = ComboSelect.new()

	# 노드 트리에 추가
	add_child(scene_manager)
	add_child(game_manager)
	add_child(input_manager)
	add_child(score_manager)
	add_child(dice_spawner)
	add_child(combo_select)

func _setup_scene() -> void:
	# 환경 설정
	scene_manager.setup_environment(self)

	# 컵 인스턴스화
	cup = CupScene.instantiate()
	cup.position = GameConstants.CUP_POSITION
	add_child(cup)

func _setup_game() -> void:
	# 게임 매니저 초기화
	game_manager.initialize()
	game_manager.setup_cup(cup)

	# 입력 매니저 초기화
	input_manager.initialize(combo_select, scene_manager.get_camera())

	# 주사위 스폰너 초기화
	dice_spawner.initialize(cup)

	# 초기 주사위 생성
	_spawn_initial_dice()

func _spawn_initial_dice() -> void:
	if not game_manager.can_draw_dice(GameConstants.HAND_SIZE):
		push_error("Bag empty at init")
		return

	var dice_defs = dice_spawner.create_dice_definitions(game_manager.bag, GameConstants.HAND_SIZE)
	dice_spawner.reset_and_spawn_all_dice(dice_defs)

	var keys = []
	for def in dice_defs:
		for color_key in GameConstants.BAG_COLOR_MAP:
			if GameConstants.BAG_COLOR_MAP[color_key] == def.color:
				keys.append(color_key)
				break
	dice_spawner.tag_spawned_nodes_with_keys(keys)

func _connect_signals() -> void:
	# 입력 매니저 시그널
	input_manager.roll_started.connect(_on_roll_started)
	input_manager.dice_selected.connect(_on_dice_selected)
	input_manager.combo_selection_toggled.connect(_on_combo_selection_toggled)

	# 게임 매니저 시그널
	game_manager.roll_finished.connect(_on_roll_finished)
	game_manager.dice_kept.connect(_on_dice_kept)

	# 주사위 스폰너 시그널
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)

	# 조합 선택 시그널
	combo_select.committed.connect(_on_combo_committed)

func _unhandled_input(event: InputEvent) -> void:
	if input_manager.handle_input(event):
		get_viewport().set_input_as_handled()

func _on_roll_started() -> void:
	await _reset_roll()
	game_manager.start_roll()
	input_manager.set_roll_in_progress(true)
	input_manager.set_selection_enabled(false)

	if cup.has_method("start_shaking"):
		cup.start_shaking()

func _on_dice_selected(dice: Node3D) -> void:
	game_manager.keep_dice(dice)

func _on_combo_selection_toggled(active: bool) -> void:
	# 필요한 경우 추가 처리
	pass

func _on_roll_finished() -> void:
	input_manager.set_roll_in_progress(false)
	input_manager.set_selection_enabled(true)
	dice_spawner.display_dice_results(game_manager.get_roll_results())

func _on_dice_kept(dice: Node3D) -> void:
	dice_spawner.remove_dice([dice])

func _on_dice_roll_finished(value: int, dice_name: String) -> void:
	game_manager.on_dice_roll_finished(value, dice_name)

	if game_manager.check_if_all_dice_finished(dice_spawner.get_dice_count()):
		_on_roll_finished()

func _on_combo_committed(nodes: Array) -> void:
	if score_manager.evaluate_and_score_combo(nodes, game_manager.get_roll_results()):
		_remove_combo_dice(nodes)

	# 선택 강조 해제
	if combo_select and combo_select.is_inside_tree():
		combo_select.clear()

func _remove_combo_dice(nodes: Array) -> void:
	game_manager.remove_combo_dice(nodes)

## 새 라운드를 위해 주사위들을 리셋합니다
## 남은 주사위들을 컵으로 재배치하고 부족한 개수만큼 새로 생성합니다
func _reset_roll() -> void:
	print("=== _reset_roll 시작 ===")

	# 먼저 컵을 원래 위치로 리셋
	cup.reset()
	print("컵 위치 리셋 완료")

	print("현재 주사위 개수: ", dice_spawner.get_dice_count())
	print("필요한 총 개수: ", GameConstants.HAND_SIZE)

	# 부족한 개수 계산
	var need = GameConstants.HAND_SIZE - dice_spawner.get_dice_count()
	print("새로 생성할 주사위 개수: ", need)

	# ★ 새로운 방식: 먼저 새 주사위 정의 생성 (물리적 생성은 나중에)
	var new_dice_defs: Array[DiceSpawner.DiceDef] = []
	if need > 0:
		if not game_manager.can_draw_dice(need):
			print("⚠️ Bag empty on reset_roll (need=", need, ")")
			game_manager.end_challenge_due_to_empty_bag()
			return
		new_dice_defs = dice_spawner.create_new_dice_definitions(game_manager.bag, need)
		print("새 주사위 정의 생성됨: ", new_dice_defs.size())

	# ★ 핵심: 재활용과 새 생성을 동시에 처리
	await dice_spawner.reset_and_spawn_all_dice(new_dice_defs)
	
	game_manager.dice_in_cup_count = dice_spawner.get_dice_count()
	print("최종 주사위 개수: ", dice_spawner.get_dice_count())
	print("=== _reset_roll 완료 - 모든 주사위 정착됨 ===")

# 마우스 릴리즈 처리
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and game_manager.is_roll_in_progress():
			_on_mouse_release()

func _on_mouse_release() -> void:
	# 컵 흔들기 중지
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()

	# 주사위에 힘 가하기
	dice_spawner.apply_dice_impulse()

	# 컵 쏟기
	if cup.has_method("pour"):
		await cup.pour()
