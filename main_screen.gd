extends Control
class_name MainScreen

# === UI 노드 참조 ===
@onready var stage_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/StageLabel
@onready var target_score_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/TargetScoreLabel
@onready var current_score_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/CurrentScoreLabel
@onready var turns_left_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/TurnsLeftLabel
@onready var invests_left_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/InvestsLeftLabel
@onready var view_dice_bag_button: Button = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/ViewDiceBagButton
@onready var submit_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/SubmitButton
@onready var invest_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/InvestButton
@onready var turn_end_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/TurnEndButton
@onready var result_label: Label = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/ResultLabel
@onready var sub_viewport: SubViewport = $HSplitContainer/GameArea/RollingArea/SubViewport
@onready var rolling_area: SubViewportContainer = $HSplitContainer/GameArea/RollingArea
# === 3D 씬 참조 ===
var world_3d: Node3D
var runtime_container: Node3D  # 런타임 생성 노드들을 위한 컨테이너
var scene_manager: SceneManager
var game_manager: GameManager
var input_manager: InputManager
var score_manager: ScoreManager
var dice_spawner: DiceSpawner
var combo_select: ComboSelect
var cup: Node3D
var invested_dice: Array[Node3D] = []

# === 리소스 로드 ===
const CupScene := preload("res://cup.tscn")
const DiceFaceImageScene = preload("res://scripts/components/dice_face_image.tscn")
const DiceBagPopupScene = preload("res://scripts/components/dice_bag_popup.tscn")
const DiceFaceTextureCache = preload("res://scripts/utils/dice_face_texture_cache.gd")

const MAX_INVESTED_DICE = 10

var dice_bag_popup: Window

@onready var invested_dice_container: HBoxContainer = $HSplitContainer/GameArea/FieldArea/InvestedDiceContainer

func _ready() -> void:
	# 3D 월드 생성
	world_3d = Node3D.new()
	world_3d.name = "World3D"
	world_3d.owner = null
	world_3d.scene_file_path = ""
	sub_viewport.add_child(world_3d)

	# 런타임 컨테이너 생성 (동적 노드들용)
	runtime_container = Node3D.new()
	runtime_container.name = "RuntimeContainer"
	runtime_container.owner = null  # 씬에 저장되지 않음
	runtime_container.scene_file_path = ""
	runtime_container.set_meta("_edit_lock_", true)
	runtime_container.set_meta("_editor_description_", "Runtime Container - Do Not Save")
	world_3d.add_child(runtime_container)

	# 팝업 초기화
	dice_bag_popup = DiceBagPopupScene.instantiate()
	add_child(dice_bag_popup)

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
	dice_spawner.initialize(cup, runtime_container)
	_invest_initial_dice()
	_spawn_initial_dice()

func _invest_initial_dice() -> void:
	if not game_manager.can_draw_dice(5):
		push_error("Not enough dice in bag for initial investment")
		return

	var dice_colors = dice_spawner.create_dice_colors_from_bag(game_manager.bag, 5)

	for i in range(dice_colors.size()):
		var color = dice_colors[i]
		var value = randi_range(1, 6)

		var color_key = ""
		for key in ComboRules.BAG_COLOR_MAP:
			if ComboRules.BAG_COLOR_MAP[key] == color:
				color_key = key
				var atlas = TextureCache.get_atlas(color_key)
				if atlas == null:
					print("ERROR in _invest_initial_dice: Atlas not found for color_key: ", color_key)
				var display = DiceFaceImageScene.instantiate()
				display.custom_minimum_size = Vector2(80, 80)
				display.name = "invested_dice_init_" + str(i)
				invested_dice_container.add_child(display)
				display.set_face(value, atlas)
				display.value = value
				display.dice_color = color

func _spawn_initial_dice() -> void:
	if not game_manager.can_draw_dice(GameConstants.HAND_SIZE):
		push_error("Bag empty at init")
		return
	var dice_colors = dice_spawner.create_dice_colors_from_bag(game_manager.bag, GameConstants.HAND_SIZE)
	dice_spawner.reset_and_spawn_all_dice(dice_colors)
	var keys = []
	for color in dice_colors:
		for color_key in GameConstants.BAG_COLOR_MAP:
			if GameConstants.BAG_COLOR_MAP[color_key] == color:
				keys.append(color_key)
				break
	dice_spawner.tag_spawned_nodes_with_keys(keys)

func _connect_signals() -> void:
	input_manager.roll_started.connect(_on_roll_started)
	game_manager.roll_finished.connect(_on_roll_finished)
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)
	
	# UI 버튼 연결
	submit_button.pressed.connect(_on_submit_pressed)
	invest_button.pressed.connect(_on_invest_pressed)
	turn_end_button.pressed.connect(_on_turn_end_pressed)
	view_dice_bag_button.pressed.connect(_on_view_dice_bag_pressed)

	# 3D 뷰포트 입력 연결
	rolling_area.gui_input.connect(_on_rolling_area_gui_input)

func _update_ui_from_gamestate() -> void:
	update_stage(Main.stage)
	update_target_score(Main.target_score)
	update_current_score(Main.current_score)
	update_turns_left(Main.turns_left)
	update_invests_left(Main.invests_left)

func _on_rolling_area_gui_input(event: InputEvent) -> void:
	if input_manager.handle_input(event):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and game_manager.is_roll_in_progress():
			_on_mouse_release()
			get_viewport().set_input_as_handled()

func _on_roll_started() -> void:
	combo_select.exit()
	await _reset_roll()
	game_manager.start_roll()
	input_manager.set_roll_in_progress(true)
	if cup.has_method("start_shaking"):
		cup.start_shaking()

func _on_roll_finished() -> void:
	input_manager.set_roll_in_progress(false)
	combo_select.enter()
	dice_spawner.display_dice_results(game_manager.get_roll_results())

func _on_dice_roll_finished(value: int, dice_name: String) -> void:
	game_manager.on_dice_roll_finished(value, dice_name)
	# check_if_all_dice_finished에서 roll_finished 시그널을 emit하므로
	# 여기서 직접 _on_roll_finished를 호출하면 중복 실행됨
	# 따라서 시그널만 기다림
	game_manager.check_if_all_dice_finished(dice_spawner.get_dice_count())

func _on_submit_pressed() -> void:
	var all_selected_nodes = []
	var roll_results_for_submission = {}

	var selected_3d_nodes = combo_select.get_selected_nodes()
	all_selected_nodes.append_array(selected_3d_nodes)
	var original_roll_results = game_manager.get_roll_results()
	for node in selected_3d_nodes:
		roll_results_for_submission[node.name] = original_roll_results[node.name]

	var selected_invested_nodes = []
	for node in invested_dice_container.get_children():
		if node.selected:
			all_selected_nodes.append(node)
			selected_invested_nodes.append(node)
			roll_results_for_submission[node.name] = node.value

	if all_selected_nodes.is_empty():
		print("조합을 제출하려면 먼저 주사위를 선택하세요.")
		return

	if score_manager.evaluate_and_score_combo(all_selected_nodes, roll_results_for_submission):
		_remove_combo_dice(selected_3d_nodes)
		
		for node in selected_invested_nodes:
			node.queue_free()
		
		combo_select.clear()
		Main.current_score = score_manager.get_total_score()
		_update_ui_from_gamestate()
	else:
		print("유효하지 않은 조합입니다.")

func _remove_combo_dice(nodes: Array) -> void:
	game_manager.remove_combo_dice(nodes)
	dice_spawner.remove_dice(nodes)

func _reset_roll() -> void:
	cup.reset()
	var need = GameConstants.HAND_SIZE - dice_spawner.get_dice_count()
	if need > 0:
		if not game_manager.can_draw_dice(need):
			game_manager.end_challenge_due_to_empty_bag()
			return
		var new_dice_colors = dice_spawner.create_dice_colors_from_bag(game_manager.bag, need)
		await dice_spawner.reset_and_spawn_all_dice(new_dice_colors)

	game_manager.dice_in_cup_count = dice_spawner.get_dice_count()

func _on_mouse_release() -> void:
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	dice_spawner.apply_dice_impulse()
	if cup.has_method("pour"):
		await cup.pour()

func _on_invest_pressed() -> void:
	if not combo_select.active:
		print("투자를 하려면 C키를 눌러 조합 선택 모드를 활성화하세요.")
		return
	
	if Main.invests_left <= 0:
		print("남은 투자 횟수가 없습니다.")
		return

	var nodes_to_invest = combo_select.get_selected_nodes()
	if nodes_to_invest.is_empty():
		print("투자할 주사위를 먼저 선택하세요.")
		return

	if invested_dice_container.get_child_count() + nodes_to_invest.size() > MAX_INVESTED_DICE:
		print("최대 %d개까지만 투자할 수 있습니다." % MAX_INVESTED_DICE)
		return

	combo_select.pop_selected_nodes() # Clear selection after check

	_invest_dice(nodes_to_invest)
	combo_select.exit()
	Main.invests_left -= 1
	_update_ui_from_gamestate()

func _invest_dice(nodes: Array) -> void:
	var roll_results = game_manager.get_roll_results()
	for dice_node in nodes:
		if not roll_results.has(dice_node.name): continue
		var value = roll_results[dice_node.name]
		
		var color_key = ""
		var body_color = dice_node.dice_color
		for key in ComboRules.BAG_COLOR_MAP:
			if ComboRules.BAG_COLOR_MAP[key] == body_color:
				color_key = key
				break

		var atlas = TextureCache.get_atlas(color_key)
		if atlas == null:
			print("ERROR in _invest_dice: Atlas not found for color_key: ", color_key)
			continue
		
		var display = DiceFaceImageScene.instantiate()
		display.custom_minimum_size = Vector2(80, 80)
		display.name = "invested_dice_" + str(display.get_instance_id())
		invested_dice_container.add_child(display)
		display.set_face(value, atlas)
		display.value = value
		display.dice_color = dice_node.dice_color

	_remove_combo_dice(nodes)
func _on_turn_end_pressed() -> void:
	combo_select.exit()
	if Main.turns_left > 0:
		Main.turns_left -= 1
		_update_ui_from_gamestate()

		var remaining_dice = dice_spawner.get_dice_nodes()
		for d in remaining_dice:
			d.queue_free()
		
		dice_spawner.clear_dice_nodes()
	else:
		print("No more turns left.")

func _cleanup_runtime_nodes() -> void:
	# 런타임 컨테이너의 모든 자식 노드 정리
	if runtime_container:
		for child in runtime_container.get_children():
			child.queue_free()

# 에디터에서 씬이 닫힐 때 호출되는 함수 (추가 보호)
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		_cleanup_runtime_nodes()

# 게임 종료 시에도 정리
func _exit_tree():
	_cleanup_runtime_nodes()

func _on_view_dice_bag_pressed() -> void:
	dice_bag_popup.update_counts(game_manager.bag)
	dice_bag_popup.show()


# --- Public API ---
func update_stage(stage_num: int) -> void:
	stage_label.text = "Stage: %d" % stage_num
func update_target_score(score: int) -> void:
	target_score_label.text = "목표 점수: %d" % score
func update_current_score(score: int) -> void:
	current_score_label.text = "현재 점수: %d" % score
func update_turns_left(count: int) -> void:
	turns_left_label.text = "남은 턴 수: %d" % count
func update_invests_left(count: int) -> void:
	invests_left_label.text = "남은 투자 횟수: %d" % count
func update_result_label(text: String) -> void:
	result_label.text = "예상 점수: " + text
