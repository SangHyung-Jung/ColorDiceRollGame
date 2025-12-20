extends Control
class_name MainScreen

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
@onready var view_dice_bag_button: Button = $MainLayout/InfoPanel/Panel/VBoxContainer/ViewDiceBagButton
@onready var shop_button: Button = $MainLayout/InfoPanel/Panel/VBoxContainer/ShopButton
@onready var submit_button: Button = $MainLayout/GameArea/InteractionUI/HBoxContainer/TextureRect/SubmitButton
@onready var invest_button: Button = $MainLayout/GameArea/InteractionUI/HBoxContainer/TextureRect2/InvestButton
@onready var turn_end_button: Button = $MainLayout/GameArea/InteractionUI/HBoxContainer/TextureRect3/TurnEndButton
@onready var result_label: Label = $MainLayout/GameArea/InteractionUI/HBoxContainer/ResultLabel
@onready var sub_viewport: SubViewport = $MainLayout/GameArea/RollingArea/SubViewport
@onready var rolling_area: SubViewportContainer = $MainLayout/GameArea/RollingArea
@onready var sort_by_color_button: Button = $MainLayout/GameArea/SocketArea/SortButtonsContainer/TextureRect/SortByColorButton
@onready var sort_by_number_button: Button = $MainLayout/GameArea/SocketArea/SortButtonsContainer/TextureRect2/SortByNumberButton

# === 스코어 애니메이션 UI 노드 ===
@onready var combo_name_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/ComboNameLabel
@onready var score_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/CalculationBoxes/ScoreBox/ScoreLabel
@onready var multiplier_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/CalculationBoxes/MultiplierBox/MultiplierLabel
@onready var turn_score_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/ScoreCalcBox/TurnScoreLabel

var _animation_running_score: int = 0


# === 3D 씬 참조 ===
var world_3d: Node3D
var game_manager: GameManager
var input_manager: InputManager
var score_manager: ScoreManager
var dice_spawner: DiceSpawner
var combo_select: ComboSelect
var cup: Node3D
var rolling_world: Node3D

# === 리소스 로드 ===
const RollingWorldScene = preload("res://scenes/rolling_world.tscn")
const CupScene := preload("res://cup.tscn")
const DiceBagPopupScene = preload("res://scripts/components/dice_bag_popup.tscn")
const SocketTexture = preload("res://dice_socket.png")

# === 투자 시스템 변수 ===
const MAX_INVESTED_DICE = 10
var socket_positions: Array[Vector3] = []
var invested_dice_nodes: Array[Node3D] = []

var dice_bag_popup: Window

func _ready() -> void:
	# 3D 월드 생성
	rolling_world = RollingWorldScene.instantiate()
	world_3d = rolling_world
	sub_viewport.add_child(world_3d)

	# 팝업 초기화
	dice_bag_popup = DiceBagPopupScene.instantiate()
	add_child(dice_bag_popup)

	# 초기화
	_initialize_managers()
	_initialize_score_calc_ui()
	_setup_scene()
	# await _setup_sockets()
	_setup_game()
	_connect_signals()
	
	await get_tree().process_frame
	_update_socket_positions()
	
	_update_ui_from_gamestate()
	_on_rolling_area_resized()
	
	_set_state(GameState.AWAITING_ROLL_INPUT)
func _update_socket_positions() -> void:
	var current_socket_container = get_node("MainLayout/GameArea/SocketArea/SocketContainer")
	if current_socket_container == null:
		push_error("SocketContainer not found at path: MainLayout/GameArea/SocketArea/SocketContainer")
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

	var camera = rolling_world.get_node_or_null("Camera3D")
	if not camera: return
	
	socket_positions.clear()
	var plane_y = 0.6 
	var viewport_offset = rolling_area.global_position

	for socket_ui in current_socket_container.get_children():
		var rect = socket_ui.get_global_rect()
		var screen_pos = rect.get_center()
		
		var local_viewport_pos = screen_pos - viewport_offset
		
		var ray_origin = camera.project_ray_origin(local_viewport_pos)
		var ray_normal = camera.project_ray_normal(local_viewport_pos)

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
	var sc = get_node("MainLayout/GameArea/SocketArea/SocketContainer")
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
	var camera = rolling_world.get_node("Camera3D")
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
	input_manager = InputManager.new()
	score_manager = ScoreManager.new()
	dice_spawner = DiceSpawner.new()
	combo_select = ComboSelect.new()

	world_3d.add_child(game_manager)
	world_3d.add_child(input_manager)
	world_3d.add_child(score_manager)
	world_3d.add_child(dice_spawner)
	world_3d.add_child(combo_select)

func _setup_scene() -> void:
	cup = CupScene.instantiate()
	cup.position = GameConstants.CUP_POSITION
	cup.scale = Vector3(1.1, 1.1, 1.1)
	world_3d.add_child(cup)

func _setup_game() -> void:
	game_manager.initialize()
	game_manager.setup_cup(cup)
	input_manager.initialize(combo_select, rolling_world.get_node("Camera3D")) 
	dice_spawner.initialize(cup, world_3d)
	_invest_initial_dice()
	cup._set_ceiling_collision(false)
	await _spawn_initial_dice()
	cup._set_ceiling_collision(true)

func _invest_initial_dice() -> void:
	if not game_manager.can_draw_dice(5):
		push_error("Not enough dice in bag for initial investment")
		return
# 소켓 위치가 아직 계산되지 않았을 수 있으므로 확인
	if socket_positions.is_empty():
		await _update_socket_positions()
		
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
	game_manager.roll_finished.connect(_on_roll_finished)
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)
	submit_button.pressed.connect(_on_submit_pressed)
	invest_button.pressed.connect(_on_invest_pressed)
	turn_end_button.pressed.connect(_on_turn_end_pressed)
	view_dice_bag_button.pressed.connect(_on_view_dice_bag_pressed)
	shop_button.pressed.connect(_on_shop_button_pressed)
	sort_by_color_button.pressed.connect(_on_sort_by_color_pressed)
	sort_by_number_button.pressed.connect(_on_sort_by_number_pressed)
	#rolling_area.gui_input.connect(_on_rolling_area_gui_input)
	rolling_area.resized.connect(_on_rolling_area_resized)

func _update_ui_from_gamestate() -> void:
	update_stage(Main.stage)
	update_target_score(Main.target_score)
	update_current_score(Main.current_score)
	update_turns_left(Main.turns_left)
	update_invests_left(Main.invests_left)

func _on_rolling_area_resized() -> void:
	var viewport_size = rolling_area.size
	sub_viewport.size = viewport_size
	if rolling_world and rolling_world.has_method("update_size"):
		rolling_world.update_size(viewport_size)
	call_deferred("_update_socket_positions")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		match current_state:
			GameState.AWAITING_ROLL_INPUT:
				if event.pressed:
					_on_roll_started()
					_set_state(GameState.ROLL_IN_PROGRESS)
					get_viewport().set_input_as_handled()
			
			GameState.ROLL_IN_PROGRESS:
				if not event.pressed:
					_on_mouse_release()
					_set_state(GameState.DICE_SETTLING)
					get_viewport().set_input_as_handled()
	
	if current_state == GameState.TURN_INTERACTION:
		var local_event = rolling_area.make_input_local(event)
		if input_manager.handle_input(local_event):
			get_viewport().set_input_as_handled()

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
	cup.hide()

func _on_mouse_release() -> void:
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	dice_spawner.apply_dice_impulse()
	if cup.has_method("pour"):
		await cup.pour()
		cup.hide()

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
	_play_score_animation(result, nodes)


func _initialize_score_calc_ui() -> void:
	combo_name_label.text = " "
	score_label.text = "0"
	multiplier_label.text = "0"
	turn_score_label.text = " "


func _update_animation_score(die_value: int) -> void:
	_animation_running_score += die_value
	score_label.text = str(_animation_running_score)


func _play_score_animation(result: ComboRules.ComboResult, nodes: Array) -> void:
	# 1. 입력 비활성화
	submit_button.disabled = true
	invest_button.disabled = true
	turn_end_button.disabled = true

	# 2. UI 및 애니메이션 변수 초기 상태 설정
	_animation_running_score = result.base_score
	combo_name_label.text = result.combo_name
	score_label.text = str(_animation_running_score)
	multiplier_label.text = str(result.multiplier)
	turn_score_label.text = " "
	
	var tween = create_tween().set_parallel(false)
	var current_roll_results = game_manager.get_roll_results()
	
	# 3. 주사위 애니메이션
	for die_node in nodes:
		if not is_instance_valid(die_node): continue

		var die_value = 0
		if current_roll_results.has(die_node.name):
			die_value = int(current_roll_results[die_node.name])
		elif die_node.has_meta("value"):
			die_value = die_node.get_meta("value")
		
		var original_pos = die_node.global_position
		var bounce_height = original_pos + Vector3(0, 1.5, 0)
		
		# Bounce Up
		tween.tween_property(die_node, "global_position", bounce_height, 0.2).set_ease(Tween.EASE_OUT)
		
		# 점수 업데이트 (bind 사용) 및 '띵' 효과
		tween.tween_callback(_update_animation_score.bind(die_value))
		tween.tween_interval(0.01) # 텍스트 렌더링 딜레이
		tween.tween_property(score_label, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

		# Bounce Down
		tween.tween_property(die_node, "global_position", original_pos, 0.2).set_ease(Tween.EASE_IN)
		tween.tween_interval(0.05)

	# 4. 최종 계산 및 결과 표시
	tween.tween_callback(func():
		turn_score_label.text = "= %d" % result.points
		turn_score_label.scale = Vector2(1.5, 1.5)
		var inner_tween = create_tween()
		inner_tween.tween_property(turn_score_label, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	)
	
	# 5. 게임 상태 업데이트 전 딜레이
	tween.tween_interval(1.5)
	
	# 6. 게임 상태 업데이트 및 정리
	tween.tween_callback(func():
		_remove_combo_dice(nodes)
		combo_select.clear()
		
		score_manager.total_score += result.points
		Main.current_score = score_manager.get_total_score()
		_update_ui_from_gamestate()

		_has_submitted_in_turn = true
		_update_ui_for_state()
		
		_initialize_score_calc_ui()
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
		# Use call_deferred to ensure dice are repositioned after the current physics frame
		call_deferred("_reposition_invested_dice")

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
		tween.tween_property(dice_node, "global_position", target_pos, 0.4)\
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
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
		# ★ 다음 롤을 미리 준비
		cup.reset()
		cup.show()
		await _reset_roll()
		# Reset the state to allow for a new roll
		_set_state(GameState.AWAITING_ROLL_INPUT)
	else:
		print("No more turns left.")

func _on_view_dice_bag_pressed() -> void:
	dice_bag_popup.update_counts(game_manager.bag)
	dice_bag_popup.show()

func _on_shop_button_pressed() -> void:
	get_tree().change_scene_to_file("res://shop_screen.tscn")

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
		tween.tween_property(dice_node, "global_position", target_pos, 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
func update_result_label(text: String) -> void:
	result_label.text = "예상 점수: " + text
