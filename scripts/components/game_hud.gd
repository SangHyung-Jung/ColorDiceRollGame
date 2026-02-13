extends Control
class_name GameHUD
signal go_to_shop_requested
const SCORE_ANIM_SPEED = 2

# === 게임 상태 ===
enum GameState {
	AWAITING_ROLL_INPUT, # 롤 입력을 기다리는 상태
	ROLL_IN_PROGRESS,    # 컵을 흔들고 있는 상태
	DICE_SETTLING,       # 주사위가 굴러가고 멈추길 기다리는 상태
	TURN_INTERACTION     # 턴 상호작용 (조합 선택 등) 상태
}
var current_state: GameState
var _has_submitted_in_turn: bool = false
var _has_invested_in_turn: bool = false

# === UI 노드 참조 ===
@onready var stage_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/StageLabel
@onready var target_score_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/TargetScoreLabel
@onready var current_score_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/CurrentScoreLabel
@onready var turns_left_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/TurnsLeftLabel
@onready var invests_left_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/InvestsLeftLabel
@onready var gold_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/GoldLabel
# [추가] 조커 시스템 관련 변수
const MAX_JOKER_SLOTS = 5 # 최대 조커 배치 개수 (필요에 따라 조정)
var joker_socket_positions: Array[Vector3] = []
var joker_dice_nodes: Array[Node3D] = []

# [추가] 조커 소켓 컨테이너 참조 (경로는 에디터 설정에 맞춰주세요)
@onready var joker_socket_container: Control = $MainLayout/JokerSocketContainer
@onready var joker_inventory: HBoxContainer = $MainLayout/InfoPanel/Panel/VBoxContainer/JokerInventory
@onready var view_dice_bag_button: Button = $MainLayout/InfoPanel/Panel/VBoxContainer/ViewDiceBagButton
@onready var submit_button: Button = $MainLayout/JokerSocketContainer/InteractionUI/HBoxContainer/TextureRect/SubmitButton
@onready var invest_button: Button = $MainLayout/JokerSocketContainer/InteractionUI/HBoxContainer/TextureRect2/InvestButton
@onready var turn_end_button: Button = $MainLayout/JokerSocketContainer/InteractionUI/HBoxContainer/TextureRect3/TurnEndButton
@onready var sort_by_color_button: Button = $MainLayout/JokerSocketContainer/SortButtonsContainer/TextureRect/SortByColorButton
@onready var sort_by_number_button: Button = $MainLayout/JokerSocketContainer/SortButtonsContainer/TextureRect2/SortByNumberButton

# === 스코어 애니메이션 UI 노드 ===
@onready var combo_name_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/ComboNameLabel
@onready var score_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/CalculationBoxes/ScoreBox/ScoreLabel
@onready var multiplier_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/CalculationBoxes/MultiplierBox/MultiplierLabel
@onready var turn_score_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/TurnScoreLabel
@onready var main_layout: HBoxContainer = $MainLayout

# === 3D 씬 참조 ===
var world_3d: Node3D # This will be set by GameRoot
var game_manager: GameManager
var score_manager: ScoreManager
var dice_spawner: DiceSpawner
var combo_select: ComboSelect
var score_animator: ScoreAnimator
var cup: Node3D
var rolling_world_camera: Camera3D
var floating_text_container: Control # This will be set by GameRoot

# === 리소스 로드 ===
const CupScene := preload("res://cup.tscn")
const DiceBagPopupScene = preload("res://scripts/components/dice_bag_popup.tscn")
const RoundClearPopupScene = preload("res://scenes/popups/round_clear_popup.tscn")
const ScoreAnimatorScene = preload("res://scripts/components/score_animator/ScoreAnimator.gd")
const SocketTexture = preload("res://dice_socket.png")

# === 투자 시스템 변수 ===
const MAX_INVESTED_DICE = 10
var socket_positions: Array[Vector3] = []
var invested_dice_nodes: Array[Node3D] = []

var dice_bag_popup: Window
var round_clear_popup: RoundClearPopup


func _ready() -> void:
	# 팝업 초기화
	dice_bag_popup = DiceBagPopupScene.instantiate()
	add_child(dice_bag_popup)

	round_clear_popup = RoundClearPopupScene.instantiate()
	add_child(round_clear_popup)
	
	# All other initialization is now deferred to setup_game_hud()


func setup_game_hud(p_world_3d: Node3D, p_rolling_world_camera: Camera3D, p_floating_text_container: Control) -> void:
	world_3d = p_world_3d
	rolling_world_camera = p_rolling_world_camera
	floating_text_container = p_floating_text_container
	
	_initialize_managers()
	_initialize_score_animator()
	_initialize_score_calc_ui()
	_connect_signals()
	# _setup_scene() is now called by _setup_game()
	# _setup_game() is now called by start_round_sequence

	await get_tree().process_frame
	update_socket_positions()     # 기존 투자 소켓 업데이트
	update_joker_socket_positions() # [추가] 조커 소켓 3D 좌표 계산
	
	_update_ui_from_gamestate()
	# No need for _on_rolling_area_resized() as SubViewport is removed
	
	# joker_inventory.update_display(Main.owned_jokers) # [변경] 기존 2D 인벤토리 대신 3D 표시 함수 호출
	update_joker_dice_display() # [추가] 보유 조커를 3D 주사위로 표시


func _initialize_score_animator() -> void:
	score_animator = ScoreAnimatorScene.new()
	add_child(score_animator)
	var refs = {
		"world_3d": world_3d,
		# "rolling_area": rolling_area, # Removed
		"score_label": score_label,
		"multiplier_label": multiplier_label,
		"turn_score_label": turn_score_label,
		"floating_text_container": floating_text_container,
		# "screen_flash": screen_flash, # Removed
		"main_layout": main_layout,
		"combo_name_label": combo_name_label,
		"submit_button": submit_button,
		"invest_button": invest_button,
		"turn_end_button": turn_end_button,
		"game_manager": game_manager,
		"invested_dice_nodes": invested_dice_nodes,
	}
	score_animator.initialize(refs)

func update_socket_positions() -> void:
	var current_socket_container = get_node("MainLayout/JokerSocketContainer/SocketContainer")
	if current_socket_container == null:
		push_error("SocketContainer not found at path: MainLayout/SocketArea/SocketContainer")
		return

	if current_socket_container.get_child_count() == 0:
		for i in range(MAX_INVESTED_DICE):
			var socket_ui = TextureRect.new()
			socket_ui.texture = SocketTexture
			socket_ui.custom_minimum_size = Vector2(110, 110)
			socket_ui.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			socket_ui.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			socket_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
			socket_ui.modulate = Color(255, 255, 255, 200)
			current_socket_container.add_child(socket_ui)
		await get_tree().process_frame 

	var camera = rolling_world_camera # Use the GameRoot's MainCamera
	if not camera: return
	
	socket_positions.clear()
	var plane_y = 0.6 
	# var viewport_offset = rolling_area.global_position # Removed

	for socket_ui in current_socket_container.get_children():
		var rect = socket_ui.get_global_rect()
		var screen_pos = rect.get_center()
		
		# var local_viewport_pos = screen_pos - viewport_offset # Removed - directly use screen_pos with MainCamera
		
		var ray_origin = camera.project_ray_origin(screen_pos)
		var ray_normal = camera.project_ray_normal(screen_pos)

		if ray_normal.y < -0.001:
			var t = (ray_origin.y - plane_y) / -ray_normal.y
			var world_pos = ray_origin + ray_normal * t
			socket_positions.append(world_pos)
		else:
			socket_positions.append(Vector3.ZERO)
			
	for i in range(invested_dice_nodes.size()):
		if i < socket_positions.size():
			var dice = invested_dice_nodes[i]
			if is_instance_valid(dice):
				dice.global_position = socket_positions[i]
				
func _setup_sockets():
	var sc = get_node("MainLayout/JokerSocketContainer/SocketContainer")
	if sc == null:
		push_error("SocketContainer not found in _setup_sockets")
		return

	# 1. 2D 소켓 UI 생성
	for i in range(MAX_INVESTED_DICE):
		var socket_ui = TextureRect.new()
		socket_ui.texture = SocketTexture
		socket_ui.custom_minimum_size = Vector2(80, 80)
		socket_ui.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		socket_ui.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sc.add_child(socket_ui)

	# 2. UI가 안정화될 때까지 대기
	await get_tree().process_frame
	await get_tree().process_frame

	# 3. 안정된 2D UI 위치를 기반으로 3D 좌표 계산
	var camera = rolling_world_camera # Use the GameRoot's MainCamera
	if not camera:
		push_error("Socket setup failed: Camera not found.")
		return
		
	var plane_y = 0.5 # 주사위가 바닥에 살짝 떠 있도록 높이 설정
	for socket_ui in sc.get_children():
		var rect = socket_ui.get_global_rect()
		var screen_pos = rect.get_center()
		
		var ray_origin = camera.project_ray_origin(screen_pos)
		var ray_normal = camera.project_ray_normal(screen_pos)

		if ray_normal.y < -0.001: # 0으로 나누기 방지
			var t = (ray_origin.y - plane_y) / -ray_normal.y
			var world_pos = ray_origin + ray_normal * t
			socket_positions.append(world_pos)
		else:
			push_error("Failed to calculate socket 3D position for a socket.")
			socket_positions.append(Vector3.ZERO)
	
	print("Calculated Socket 3D Positions: ", socket_positions)

func _initialize_managers() -> void:
	game_manager = GameManager.new()
	# input_manager = InputManager.new() # Removed, now in GameRoot
	score_manager = ScoreManager.new()
	dice_spawner = DiceSpawner.new()
	combo_select = ComboSelect.new()

	world_3d.add_child(game_manager)
	# world_3d.add_child(input_manager) # Removed, now in GameRoot
	world_3d.add_child(score_manager)
	world_3d.add_child(dice_spawner)
	world_3d.add_child(combo_select)

func _setup_scene() -> void:
	cup = CupScene.instantiate()
	cup.position = GameConstants.CUP_POSITION
	cup.scale = Vector3(1, 1, 1)
	world_3d.add_child(cup)
	await get_tree().process_frame      # physics 반영까지 대기
	cup.update_initial_transform()      # 확정된 위치 저장
	
func _setup_game() -> void:
	await _setup_scene()
	game_manager.initialize()
	game_manager.setup_cup(cup)
	dice_spawner.initialize(cup, world_3d)
	await _invest_initial_dice()
	await _reset_roll()  # _spawn_initial_dice() 대신 통일

func start_roll_animation() -> void:
	# This function will be connected to InputManager.roll_started
	_on_roll_started()
	_set_state(GameState.ROLL_IN_PROGRESS)

func handle_roll_release() -> void:
	if current_state == GameState.ROLL_IN_PROGRESS:
		_on_mouse_release()
		_set_state(GameState.DICE_SETTLING)

func _invest_initial_dice() -> void:
	if not game_manager.can_draw_dice(5):
		push_error("Not enough dice in bag for initial investment")
		return
# 소켓 위치가 아직 계산되지 않았을 수 있으므로 확인
	if socket_positions.is_empty():
		await update_socket_positions()
		
	var dice_colors = dice_spawner.create_dice_colors_from_bag(game_manager.bag, 5)

	for i in range(dice_colors.size()):
		var color = dice_colors[i]
		var value = randi_range(1, 6)
		var dice_color_enum = ColoredDice.color_from_godot_color(color)
		
		var dice_node = ColoredDice.new()
		world_3d.add_child(dice_node)
		dice_node.setup_dice(dice_color_enum)
		dice_node.show_face(value)
		dice_node.set_meta("value", value)
		
		dice_node.freeze = true
		
		if i < socket_positions.size():
			dice_node.global_position = socket_positions[i]
			invested_dice_nodes.append(dice_node)
		else:
			push_error("Not enough socket positions for initial investment.")
			dice_node.queue_free()


func _spawn_initial_dice() -> void:
	if not game_manager.can_draw_dice(GameConstants.HAND_SIZE):
		push_error("Bag empty at init")
		return
	var dice_colors = dice_spawner.create_dice_colors_from_bag(game_manager.bag, GameConstants.HAND_SIZE)
	await dice_spawner.reset_and_spawn_all_dice(dice_colors)
	var keys = []
	for color in dice_colors:
		for color_key in GameConstants.BAG_COLOR_MAP:
			if GameConstants.BAG_COLOR_MAP[color_key] == color:
				keys.append(color_key)
				break
	dice_spawner.tag_spawned_nodes_with_keys(keys)


func _connect_signals() -> void:
	score_manager.combo_scored_detailed.connect(_on_combo_scored_detailed)
	score_animator.animation_finished.connect(_on_score_animation_finished)
	game_manager.roll_finished.connect(_on_roll_finished)
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)
	submit_button.pressed.connect(_on_submit_pressed)
	invest_button.pressed.connect(_on_invest_pressed)
	turn_end_button.pressed.connect(_on_turn_end_pressed)
	view_dice_bag_button.pressed.connect(_on_view_dice_bag_pressed)
	sort_by_color_button.pressed.connect(_on_sort_by_color_pressed)
	sort_by_number_button.pressed.connect(_on_sort_by_number_pressed)
	#rolling_area.gui_input.connect(_on_rolling_area_gui_input) # Removed
	#rolling_area.resized.connect(_on_rolling_area_resized) # Removed
	
	round_clear_popup.continue_pressed.connect(_on_round_clear_popup_continue_pressed)
	StageManager.round_advanced.connect(_on_stage_manager_round_advanced)


func _update_ui_from_gamestate() -> void:
	update_stage(StageManager.current_stage)
	update_target_score(StageManager.get_current_target_score())
	update_current_score(Main.current_score)
	update_turns_left(Main.turns_left)
	update_invests_left(Main.invests_left)
	update_gold(Main.gold)

# func _on_rolling_area_resized() -> void: # Removed
# 	var viewport_size = rolling_area.size
# 	sub_viewport.size = viewport_size
# 	if rolling_world and rolling_world.has_method("update_size"):
# 		rolling_world.update_size(viewport_size)
# 	call_deferred("_update_socket_positions")



func _on_roll_started() -> void:
	#cup.show()
	combo_select.exit()
	#await _reset_roll()
	game_manager.start_roll()
	if cup.has_method("start_shaking"):
		cup.start_shaking()

func _on_roll_finished() -> void:
	_has_submitted_in_turn = false
	_has_invested_in_turn = false
	_set_state(GameState.TURN_INTERACTION)
	combo_select.enter()
	dice_spawner.display_dice_results(game_manager.get_roll_results())

func _on_mouse_release() -> void:
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	dice_spawner.apply_dice_impulse()
	if cup.has_method("pour"):
		await cup.pour()

func _on_dice_roll_finished(value: int, dice_name: String) -> void:
	game_manager.on_dice_roll_finished(value, dice_name)
	game_manager.check_if_all_dice_finished(dice_spawner.get_dice_count())

func _on_submit_pressed() -> void:
	var all_selected_nodes = []
	var roll_results_for_submission = {}

	var selected_3d_nodes = combo_select.get_selected_nodes()
	all_selected_nodes.append_array(selected_3d_nodes)
	var current_roll_results = game_manager.get_roll_results()
	
	for node in selected_3d_nodes:
		if current_roll_results.has(node.name):
			roll_results_for_submission[node.name] = current_roll_results[node.name]
		elif node.has_meta("value"):
			roll_results_for_submission[node.name] = node.get_meta("value")
		else:
			print("오류: 주사위 값을 찾을 수 없습니다 -> ", node.name)
			return
	if all_selected_nodes.is_empty():
		print("조합을 제출하려면 먼저 주사위를 선택하세요.")
		return

	if not score_manager.evaluate_and_score_combo(all_selected_nodes, roll_results_for_submission):
		print("유효하지 않은 조합입니다.")


func _on_combo_scored_detailed(result: ComboRules.ComboResult, nodes: Array) -> void:
	score_animator.play_animation(result, nodes)


func _on_score_animation_finished(points: int, nodes: Array) -> void:
	var new_total_score = score_manager.get_total_score() + points
	_animate_current_score(new_total_score, nodes)


func _animate_current_score(target_score: int, nodes: Array) -> void:
	var current_score_text = current_score_label.text.split(": ")[1]
	var start_score = int(current_score_text)
	
	var tween = create_tween()
	
	tween.tween_method(
		func(val): update_current_score(val),
		start_score,
		target_score,
		1.0 / SCORE_ANIM_SPEED
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_callback(func():
		_remove_combo_dice(nodes)
		combo_select.clear()
		
		score_manager.total_score = target_score
		Main.current_score = target_score
		
		_has_submitted_in_turn = true
		_update_ui_for_state()
		_initialize_score_calc_ui()

		# 라운드 클리어 확인
		if Main.current_score >= StageManager.get_current_target_score():
			_handle_round_clear()

	)

func _remove_combo_dice(nodes: Array) -> void:
	game_manager.remove_combo_dice(nodes)
	dice_spawner.remove_dice(nodes)

	var reposition_needed = false
	for node in nodes:
		if invested_dice_nodes.has(node):
			invested_dice_nodes.erase(node)
			reposition_needed = true
	
	if reposition_needed:
		call_deferred("_reposition_invested_dice")


func _initialize_score_calc_ui() -> void:
	combo_name_label.text = " "
	score_label.text = "0"
	multiplier_label.text = "0"


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

func _on_invest_pressed() -> void:
	if not combo_select.active:
		print("투자를 하려면 C키를 눌러 조합 선택 모드를 활성화하세요.")
		return
	if Main.invests_left <= 0:
		print("남은 투자 횟수가 없습니다.")
		return

	var selected_nodes = combo_select.pop_selected_nodes() # Get all selected nodes
	if selected_nodes.is_empty():
		print("투자할 주사위를 먼저 선택하세요.")
		return

	var nodes_to_actually_invest: Array = []
	for node in selected_nodes:
		if not invested_dice_nodes.has(node): # Check if NOT already invested
			nodes_to_actually_invest.append(node)
		else:
			print("경고: 이미 투자된 주사위는 다시 투자할 수 없습니다: ", node.name)

	if nodes_to_actually_invest.is_empty():
		print("유효한 투자 대상 주사위가 없습니다.")
		return

	if invested_dice_nodes.size() + nodes_to_actually_invest.size() > MAX_INVESTED_DICE:
		print("최대 %d개까지만 투자할 수 있습니다." % MAX_INVESTED_DICE)
		return

	_invest_dice(nodes_to_actually_invest) # Pass only the new dice
	combo_select.exit()
	Main.invests_left -= 1
	_update_ui_from_gamestate()
	
	_has_invested_in_turn = true
	_update_ui_for_state()
func _invest_dice(nodes: Array):
	var current_results = game_manager.get_roll_results()
	
	for dice_node in nodes:
		var next_socket_index = invested_dice_nodes.size()
		if next_socket_index >= socket_positions.size():
			push_error("No more available sockets.")
			break
		
		var target_pos = socket_positions[next_socket_index]

		if current_results.has(dice_node.name):
			dice_node.set_meta("value", current_results[dice_node.name])
		dice_node.freeze = true
		dice_node.linear_velocity = Vector3.ZERO
		dice_node.angular_velocity = Vector3.ZERO
		
		var tween = create_tween()
		tween.tween_property(dice_node, "global_position", target_pos, 0.4)			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
		invested_dice_nodes.append(dice_node)
		
		# 게임 매니저 결과에서만 제거 (객체 삭제 X)
		if game_manager.get_roll_results().has(dice_node.name):
			game_manager.get_roll_results().erase(dice_node.name)

	# 스포너 관리 목록에서 제거
	dice_spawner.remove_dice(nodes)

func _on_turn_end_pressed() -> void:
	combo_select.exit()
	if Main.turns_left > 0:
		Main.turns_left -= 1
		_update_ui_from_gamestate()
		var remaining_dice = dice_spawner.get_dice_nodes()
		for d in remaining_dice:
			d.queue_free()
		dice_spawner.clear_dice_nodes()
		await _reset_roll()
		# Reset the state to allow for a new roll
		_set_state(GameState.AWAITING_ROLL_INPUT)
	else:
		print("No more turns left.")

func _on_view_dice_bag_pressed() -> void:
	dice_bag_popup.update_counts(game_manager.bag)
	dice_bag_popup.show()

func _on_sort_by_color_pressed() -> void:
	if invested_dice_nodes.is_empty():
		return
	
	# Sort by the integer value of the DiceColor enum
	invested_dice_nodes.sort_custom(func(a, b): return a.current_dice_color < b.current_dice_color)
	_reposition_invested_dice()

func _on_sort_by_number_pressed() -> void:
	if invested_dice_nodes.is_empty():
		return

	# Sort by the 'value' meta-data
	invested_dice_nodes.sort_custom(func(a, b): return a.get_meta("value") < b.get_meta("value"))
	_reposition_invested_dice()

func _reposition_invested_dice() -> void:
	# Reposition the dice in the UI according to the sorted array order
	for i in range(invested_dice_nodes.size()):
		var dice_node = invested_dice_nodes[i]
		if not is_instance_valid(dice_node):
			continue
			
		var target_pos = socket_positions[i]
		
		# Use a tween for smooth movement
		var tween = create_tween()
		tween.tween_property(dice_node, "global_position", target_pos, 0.3)			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# [추가] 조커 소켓의 2D UI 위치를 3D 월드 좌표로 변환하는 함수
func update_joker_socket_positions() -> void:
	if joker_socket_container == null:
		return

	# UI 슬롯이 비어있다면 미리 채워줌 (위치 계산용)
	if joker_socket_container.get_child_count() == 0:
		for i in range(MAX_JOKER_SLOTS):
			var socket_ui = TextureRect.new()
			# const SocketTexture = preload("res://dice_socket.png") - Already defined at the top
			socket_ui.texture = SocketTexture # 기존 소켓 텍스처 재사용
			socket_ui.custom_minimum_size = Vector2(80, 80) # 크기 조정
			socket_ui.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			socket_ui.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			socket_ui.modulate = Color(1, 1, 1, 0.5) # 약간 투명하게
			joker_socket_container.add_child(socket_ui)
		await get_tree().process_frame # UI 레이아웃 적용 대기

	var camera = rolling_world_camera
	if not camera: return

	joker_socket_positions.clear()
	var plane_y = 0.6 # 투자 주사위와 같은 높이 또는 약간 다르게 설정

	for socket_ui in joker_socket_container.get_children():
		var rect = socket_ui.get_global_rect()
		var screen_pos = rect.get_center()

		var ray_origin = camera.project_ray_origin(screen_pos)
		var ray_normal = camera.project_ray_normal(screen_pos)

		if ray_normal.y < -0.001:
			var t = (ray_origin.y - plane_y) / -ray_normal.y
			var world_pos = ray_origin + ray_normal * t
			joker_socket_positions.append(world_pos)
		else:
			joker_socket_positions.append(Vector3.ZERO)

	# 이미 떠있는 조커 주사위들의 위치도 갱신
	_reposition_joker_dice()

# [추가] 보유한 조커 목록(Main.owned_jokers)을 기반으로 3D 주사위 생성 및 배치
func update_joker_dice_display() -> void:
	# 기존 조커 주사위 제거
	for dice in joker_dice_nodes:
		if is_instance_valid(dice):
			dice.queue_free()
	joker_dice_nodes.clear()

	var owned_jokers = Main.owned_jokers # Main에서 보유 조커 리스트 가져옴

	for i in range(owned_jokers.size()):
		if i >= joker_socket_positions.size():
			break # 소켓 수보다 많으면 중단 (혹은 페이지 처리)

		var joker_data = owned_jokers[i]
		var target_pos = joker_socket_positions[i]

		# 조커 주사위 생성 (ColoredDice 활용)
		var dice_node = ColoredDice.new()
		world_3d.add_child(dice_node)

		# 흰색 베이스로 생성
		dice_node.setup_dice(ColoredDice.DiceColor.WHITE)

		# 조커 이미지 적용 (CSV 데이터에 'image_path' 키가 있다고 가정)
		if joker_data.has("image_path"):
			dice_node.set_joker_texture(joker_data["image_path"])

		# 물리 고정 및 위치 설정
		dice_node.freeze = true
		dice_node.global_position = target_pos
		dice_node.rotation_degrees = Vector3(0, 180, 0) # 정면을 보게 회전 (필요시 조정)

		joker_dice_nodes.append(dice_node)

# [추가] 조커 주사위 위치 재조정 (화면 크기 변경 대응 등)
func _reposition_joker_dice() -> void:
	for i in range(joker_dice_nodes.size()):
		if i < joker_socket_positions.size():
			var dice = joker_dice_nodes[i]
			if is_instance_valid(dice):
				# Tween으로 부드럽게 이동
				var tween = create_tween()
				tween.tween_property(dice, "global_position", joker_socket_positions[i], 0.3).set_trans(Tween.TRANS_SINE)

# ============================================================================
# 상태 관리
# ============================================================================

func _set_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	_update_ui_for_state()

func _update_ui_for_state() -> void:
	match current_state:
		GameState.AWAITING_ROLL_INPUT, GameState.DICE_SETTLING:
			submit_button.disabled = true
			invest_button.disabled = true
			turn_end_button.disabled = true
			
			view_dice_bag_button.disabled = false
			sort_by_color_button.disabled = false
			sort_by_number_button.disabled = false
		
		GameState.ROLL_IN_PROGRESS:
			submit_button.disabled = true
			invest_button.disabled = true
			turn_end_button.disabled = true
			view_dice_bag_button.disabled = true
			sort_by_color_button.disabled = true
			sort_by_number_button.disabled = true

		GameState.TURN_INTERACTION:
			# Mutual exclusion logic
			submit_button.disabled = _has_invested_in_turn
			invest_button.disabled = _has_submitted_in_turn
			
			# End button activation logic
			turn_end_button.disabled = not (_has_submitted_in_turn or _has_invested_in_turn)

			# Other buttons are always enabled in this state
			view_dice_bag_button.disabled = false
			sort_by_color_button.disabled = false
			sort_by_number_button.disabled = false

func _handle_round_clear() -> void:
	# 1. 골드 보상 계산 및 Main.gold에 반영
	var rewards = StageManager.calculate_round_rewards()
	
	# 2. 팝업에 라운드 결과와 보상 정보를 전달하여 표시
	round_clear_popup.setup(
		StageManager.current_round,
		StageManager.get_current_target_score(),
		Main.current_score,
	rewards
	)
	round_clear_popup.popup_centered()

func _on_round_clear_popup_continue_pressed() -> void:
	emit_signal("go_to_shop_requested")

func start_round_sequence() -> void:
	# This function will be called by GameRoot when transitioning from shop to game
	combo_select.exit()
	_initialize_score_calc_ui()
	joker_inventory.update_display(Main.owned_jokers)
	_set_state(GameState.AWAITING_ROLL_INPUT)
	_update_ui_from_gamestate()
	await _setup_game()

func _on_stage_manager_round_advanced(new_stage: int, new_round: int) -> void:
	# 1. 새 라운드를 위해 ScoreManager의 점수 초기화
	score_manager.reset_score()
	# 2. UI 업데이트 (새 목표 점수, 현재 점수 0 등)
	_update_ui_from_gamestate()
	
	# 3. 이전 라운드의 모든 주사위와 컵 제거
	if is_instance_valid(cup):
		cup.queue_free()
		
	var all_dice = dice_spawner.get_dice_nodes() + invested_dice_nodes
	for d in all_dice:
		if is_instance_valid(d):
			d.queue_free()
	dice_spawner.clear_dice_nodes()
	invested_dice_nodes.clear()
	
	_has_submitted_in_turn = false
	_has_invested_in_turn = false

	# 4. 새 라운드를 완벽하게 새로 설정 (주사위 주머니 리셋 포함)
	# Removed _setup_game() as it's now called by start_round_sequence()

	# 5. 게임 상태를 롤 입력 대기로 전환
	_set_state(GameState.AWAITING_ROLL_INPUT)



# --- Public API ---
func update_stage(stage_num: int) -> void:
	stage_label.text = "Stage: %d" % stage_num
func update_target_score(score: int) -> void:
	target_score_label.text = "Target Score: %d" % score
func update_current_score(score: int) -> void:
	current_score_label.text = "Current Score: %d" % score
func update_turns_left(count: int) -> void:
	turns_left_label.text = "Left Turns: %d" % count
func update_invests_left(count: int) -> void:
	invests_left_label.text = "Left Invests: %d" % count
func update_gold(amount: int) -> void:
	gold_label.text = "Gold: $%d" % amount
