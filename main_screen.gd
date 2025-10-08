
extends Control
class_name MainScreen

# === UI 노드 참조 ===
@onready var stage_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/StageLabel
@onready var target_score_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/TargetScoreLabel
@onready var current_score_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/CurrentScoreLabel
@onready var hands_left_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/HandsLeftLabel
@onready var invests_left_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/InvestsLeftLabel
@onready var submit_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/SubmitButton
@onready var invest_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/InvestButton
@onready var result_label: Label = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/ResultLabel
@onready var sub_viewport: SubViewport = $HSplitContainer/GameArea/RollingArea/SubViewport
@onready var rolling_area: SubViewportContainer = $HSplitContainer/GameArea/RollingArea

# === 3D 씬 참조 ===
var world_3d: Node3D
var scene_manager: SceneManager
var game_manager: GameManager
var input_manager: InputManager
var score_manager: ScoreManager
var dice_spawner: DiceSpawner
var combo_select: ComboSelect
var cup: Node3D

# === 리소스 로드 ===
const CupScene := preload("res://cup.tscn")

func _ready() -> void:
	# 3D 월드 생성
	world_3d = Node3D.new()
	sub_viewport.add_child(world_3d)

	# 초기화
	_initialize_managers()
	_setup_scene()
	_setup_game()
	_connect_signals()
	_update_ui_from_gamestate()

func _initialize_managers() -> void:
	scene_manager = SceneManager.new()
	game_manager = GameManager.new()
	input_manager = InputManager.new()
	score_manager = ScoreManager.new()
	dice_spawner = DiceSpawner.new()
	combo_select = ComboSelect.new()

	world_3d.add_child(scene_manager)
	world_3d.add_child(game_manager)
	world_3d.add_child(input_manager)
	world_3d.add_child(score_manager)
	world_3d.add_child(dice_spawner)
	world_3d.add_child(combo_select)

func _setup_scene() -> void:
	scene_manager.setup_environment(world_3d)
	cup = CupScene.instantiate()
	cup.position = GameConstants.CUP_POSITION
	world_3d.add_child(cup)

func _setup_game() -> void:
	game_manager.initialize()
	game_manager.setup_cup(cup)
	input_manager.initialize(combo_select, scene_manager.get_camera())
	dice_spawner.initialize(cup)
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
	input_manager.roll_started.connect(_on_roll_started)
	input_manager.dice_selected.connect(_on_dice_selected)
	game_manager.roll_finished.connect(_on_roll_finished)
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)
	combo_select.committed.connect(_on_combo_committed)
	
	# UI 버튼 연결
	submit_button.pressed.connect(_on_submit_pressed)
	invest_button.pressed.connect(_on_invest_pressed)

	# 3D 뷰포트 입력 연결
	rolling_area.gui_input.connect(_on_rolling_area_gui_input)

func _update_ui_from_gamestate() -> void:
	update_stage(Main.stage)
	update_target_score(Main.target_score)
	update_current_score(Main.current_score)
	update_hands_left(Main.hands_left)
	update_invests_left(Main.invests_left)

func _on_rolling_area_gui_input(event: InputEvent) -> void:
	# 마우스 클릭 시 롤 시작 또는 주사위 선택
	if input_manager.handle_input(event):
		get_viewport().set_input_as_handled()
		return

	# 마우스 릴리즈 시 컵에서 주사위 쏟기
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and game_manager.is_roll_in_progress():
			_on_mouse_release()
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

func _on_roll_finished() -> void:
	input_manager.set_roll_in_progress(false)
	input_manager.set_selection_enabled(true)
	dice_spawner.display_dice_results(game_manager.get_roll_results())

func _on_dice_roll_finished(value: int, dice_name: String) -> void:
	game_manager.on_dice_roll_finished(value, dice_name)
	if game_manager.check_if_all_dice_finished(dice_spawner.get_dice_count()):
		_on_roll_finished()

func _on_combo_committed(nodes: Array) -> void:
	if score_manager.evaluate_and_score_combo(nodes, game_manager.get_roll_results()):
		_remove_combo_dice(nodes)
		Main.current_score = score_manager.get_total_score()
		_update_ui_from_gamestate()

	if combo_select and combo_select.is_inside_tree():
		combo_select.clear()

func _remove_combo_dice(nodes: Array) -> void:
	game_manager.remove_combo_dice(nodes)

func _reset_roll() -> void:
	cup.reset()
	var need = GameConstants.HAND_SIZE - dice_spawner.get_dice_count()
	if need > 0:
		if not game_manager.can_draw_dice(need):
			game_manager.end_challenge_due_to_empty_bag()
			return
		var new_dice_defs = dice_spawner.create_new_dice_definitions(game_manager.bag, need)
		await dice_spawner.reset_and_spawn_all_dice(new_dice_defs)
	
	game_manager.dice_in_cup_count = dice_spawner.get_dice_count()

func _on_mouse_release() -> void:
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	dice_spawner.apply_dice_impulse()
	if cup.has_method("pour"):
		await cup.pour()

# --- UI 연결 함수 ---
func _on_submit_pressed() -> void:
	print("조합 제출 버튼 눌림")
	# TODO: 조합 제출 로직 연결
	# 예: combo_select.commit_selection()
	
func _on_invest_pressed() -> void:
	print("투자 버튼 눌림")
	# TODO: 투자 로직 연결

# --- Public API ---
func update_stage(stage_num: int) -> void:
	stage_label.text = "Stage: %d" % stage_num
func update_target_score(score: int) -> void:
	target_score_label.text = "목표 점수: %d" % score
func update_current_score(score: int) -> void:
	current_score_label.text = "현재 점수: %d" % score
func update_hands_left(count: int) -> void:
	hands_left_label.text = "남은 제출 횟수: %d" % count
func update_invests_left(count: int) -> void:
	invests_left_label.text = "남은 투자 횟수: %d" % count
func update_result_label(text: String) -> void:
	result_label.text = "예상 점수: " + text
