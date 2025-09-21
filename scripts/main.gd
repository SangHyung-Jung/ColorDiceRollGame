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
var journey_manager: JourneyManager # 여정 관리자
var joker_manager: JokerManager      # 조커 관리자

# === 리소스 로드 ===
const CupScene := preload("res://cup.tscn")  # 컵 씬 파일
@onready var GameUIScene = load("res://scenes/ui/game_ui.tscn") # 게임 UI 씬 파일

# === UI 참조 ===
var game_ui: GameUI # Reference to the UI instance

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

	# JokerManager 생성 및 추가
	joker_manager = JokerManager.new()
	add_child(joker_manager)

	# JourneyManager 생성 및 추가
	journey_manager = JourneyManager.new()
	add_child(journey_manager)

	# GameUI 생성 및 추가
	game_ui = GameUIScene.instantiate()
	add_child(game_ui)

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
	combo_select.initialize(game_manager)

	# 주사위 스폰너 초기화
	dice_spawner.initialize(cup)

	# 초기 주사위 생성
	_spawn_initial_dice()

	# 모든 매니저 초기화 후 JourneyManager 초기화
	_post_initialize_managers()

func _post_initialize_managers() -> void:
	journey_manager.initialize(get_game_context()) # Pass game context

# Helper to get the game context for boss rules
func get_game_context() -> Dictionary:
	return {
		"game_manager": game_manager,
		"score_manager": score_manager,
		"dice_spawner": dice_spawner,
		"input_manager": input_manager,
		"game_ui": game_ui,
		"journey_manager": journey_manager # Reference to itself
	}

func _spawn_initial_dice() -> void:
	if not game_manager.can_draw_dice(GameConstants.HAND_SIZE):
		push_error("Bag empty at init")
		return

	var dice_defs = dice_spawner.create_dice_definitions(game_manager.bag, GameConstants.HAND_SIZE)
	dice_spawner.spawn_dice_in_cup(dice_defs)

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
	input_manager.invest_selection_toggled.connect(_on_invest_selection_toggled)
	input_manager.dice_selected_for_invest.connect(_on_dice_selected_for_invest)
	input_manager.dice_highlight_requested.connect(game_manager.highlight_dice)

	# 게임 매니저 시그널
	game_manager.roll_finished.connect(_on_roll_finished)
	game_manager.dice_kept.connect(_on_dice_kept)
	game_manager.hand_dice_updated.connect(game_ui.update_hand_dice_display)
	game_manager.field_dice_updated.connect(game_ui.update_field_dice_display)

	# 주사위 스폰너 시그널
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)

	# 조합 선택 시그널
	combo_select.committed.connect(_on_combo_committed)

	# UI 시그널
	score_manager.combo_scored.connect(game_ui.update_score)
	game_manager.roll_finished.connect(_on_game_manager_roll_finished)
	game_ui.submit_combo_pressed.connect(_on_submit_combo_pressed)
	game_ui.invest_pressed.connect(_on_invest_pressed)

	# JourneyManager 시그널
	journey_manager.stage_changed.connect(game_ui.update_stage_info)
	journey_manager.player_stats_updated.connect(game_ui._on_player_stats_updated)
	journey_manager.boss_rule_applied.connect(game_ui.update_boss_rule)

func _unhandled_input(event: InputEvent) -> void:
	if input_manager.handle_input(event):
		get_viewport().set_input_as_handled()

func _on_roll_started() -> void:
	game_manager.start_roll()
	input_manager.set_roll_in_progress(true)
	input_manager.set_selection_enabled(false)
	_reset_roll()
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
		# Inform JourneyManager about the successful submission
		journey_manager.process_submission(score_manager.get_total_score()) # Pass the score from the combo

	# 선택 강조 해제
	if combo_select and combo_select.is_inside_tree():
		combo_select.clear()

func _remove_combo_dice(nodes: Array) -> void:
	game_manager.remove_combo_dice(nodes)

## 새 라운드를 위해 주사위들을 리셋합니다
## 남은 주사위들을 컵으로 재배치하고 부족한 개수만큼 새로 생성합니다
func _reset_roll() -> void:
	print("=== _reset_roll 시작 ===")

	# Clear hand and field dice in game_manager
	game_manager.hand_dice.clear()
	game_manager.field_dice.clear()
	game_manager.field_dice_updated.emit(game_manager._get_dice_display_data(game_manager.field_dice)) # Update UI

	# 남은 주사위들을 컵으로 재배치
	dice_spawner.reset_dice_in_cup()
	game_manager.dice_in_cup_count = dice_spawner.get_dice_count()

	print("리셋 후 주사위 개수: ", dice_spawner.get_dice_count())
	print("필요한 총 개수: ", GameConstants.HAND_SIZE)

	# 부족한 개수만큼 새 주사위 생성
	var need = GameConstants.HAND_SIZE - dice_spawner.get_dice_count()
	print("새로 생성할 주사위 개수: ", need)

	if need > 0:
		if not game_manager.can_draw_dice(need):
			print("⚠️ Bag empty on reset_roll (need=", need, ")")
			game_manager.end_challenge_due_to_empty_bag()
			return

		var new_dice_defs = dice_spawner.create_new_dice_definitions(game_manager.bag, need)
		print("새 주사위 정의 생성됨: ", new_dice_defs.size())
		dice_spawner.spawn_dice_in_cup(new_dice_defs)
		print("새 주사위 스폰 완료")

	# Populate game_manager.hand_dice with all currently spawned dice
	game_manager.hand_dice.append_array(dice_spawner.get_dice_nodes())
	game_manager.hand_dice_updated.emit(game_manager._get_dice_display_data(game_manager.hand_dice)) # Update UI

	print("최종 주사위 개수: ", dice_spawner.get_dice_count())
	print("=== _reset_roll 완료 ===")

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

func _on_game_manager_roll_finished() -> void:
	# Update UI with current dice displays
	game_ui.update_hand_dice_display(game_manager._get_dice_display_data(game_manager.hand_dice))
	game_ui.update_field_dice_display(game_manager._get_dice_display_data(game_manager.field_dice))
	# The submission/investment counts are updated via journey_manager.player_stats_updated signal

func _on_submit_combo_pressed() -> void:
	print("Submit Combo button pressed!")
	input_manager.toggle_combo_selection()
	# TODO: Implement actual combo submission logic and pass real score
	# journey_manager.process_submission(score_manager.get_total_score()) # Placeholder score

func _on_invest_pressed() -> void:
	print("Invest button pressed!")
	input_manager.toggle_invest_selection()

func _on_invest_selection_toggled(active: bool) -> void:
	if active:
		game_ui.update_boss_rule("투자할 주사위를 선택하세요 (우클릭 확정)") # Use boss rule label for temporary message
	else:
		var current_boss_rule_id = journey_manager.get_current_stage_info().boss_rule_id
		if not current_boss_rule_id.is_empty():
			var boss_rule_data = DataManager.get_boss_rule_by_id(current_boss_rule_id)
			if boss_rule_data != null:
				game_ui.update_boss_rule(boss_rule_data.rule_name + ": " + boss_rule_data.description)
			else:
				game_ui.update_boss_rule("") # Clear if rule not found
		else:
			game_ui.update_boss_rule("") # Clear for normal opponents

func _on_dice_selected_for_invest(selected_dice: Array[Node3D]) -> void:
	print("Dice selected for invest: ", selected_dice.size())
	game_manager.move_dice_to_field(selected_dice)
	
	# Position the dice visually
	dice_spawner.position_dice_in_field(game_manager.field_dice)
	dice_spawner.position_dice_in_hand(game_manager.hand_dice)
	
	journey_manager.process_investment()
	_reset_roll() # Replenish hand after investment
