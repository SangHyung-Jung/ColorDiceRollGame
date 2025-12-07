extends Control
class_name MainScreen

# === UI 노드 참조 ===
@onready var stage_label: Label = $MainLayout/InfoPanel/VBoxContainer/StageLabel
@onready var target_score_label: Label = $MainLayout/InfoPanel/VBoxContainer/TargetScoreLabel
@onready var current_score_label: Label = $MainLayout/InfoPanel/VBoxContainer/CurrentScoreLabel
@onready var turns_left_label: Label = $MainLayout/InfoPanel/VBoxContainer/TurnsLeftLabel
@onready var invests_left_label: Label = $MainLayout/InfoPanel/VBoxContainer/InvestsLeftLabel
@onready var view_dice_bag_button: Button = $MainLayout/InfoPanel/VBoxContainer/ViewDiceBagButton
@onready var submit_button: Button = $MainLayout/GameArea/InteractionUI/HBoxContainer/SubmitButton
@onready var invest_button: Button = $MainLayout/GameArea/InteractionUI/HBoxContainer/InvestButton
@onready var turn_end_button: Button = $MainLayout/GameArea/InteractionUI/HBoxContainer/TurnEndButton
@onready var result_label: Label = $MainLayout/GameArea/InteractionUI/HBoxContainer/ResultLabel
@onready var sub_viewport: SubViewport = $MainLayout/GameArea/RollingArea/SubViewport
@onready var rolling_area: SubViewportContainer = $MainLayout/GameArea/RollingArea
@onready var socket_container: HBoxContainer = $MainLayout/GameArea/SocketContainer

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
	_setup_scene()
	# await _setup_sockets()
	_setup_game()
	_connect_signals()
	
	await get_tree().process_frame
	_update_socket_positions()
	
	_update_ui_from_gamestate()
	_on_rolling_area_resized()
	
func _update_socket_positions() -> void:
	socket_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 1. 2D 소켓 UI가 생성되었는지 확인
	if socket_container.get_child_count() == 0:
		# 소켓 UI가 없다면 생성 (기존 로직 유지)
		for i in range(MAX_INVESTED_DICE):
			var socket_ui = TextureRect.new()
			socket_ui.texture = SocketTexture
			socket_ui.custom_minimum_size = Vector2(110, 110)
			socket_ui.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			socket_ui.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			socket_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
			socket_container.add_child(socket_ui)
		await get_tree().process_frame 

	var camera = rolling_world.get_node_or_null("Camera3D")
	if not camera: return
	
	socket_positions.clear()
	# 주사위 중심 높이 설정 (주사위 크기가 1.2이므로 반절인 0.6 정도가 적당함)
	var plane_y = 0.6 
	
	# ★ 핵심 수정: 3D 뷰포트 컨테이너의 글로벌 위치 가져오기
	var viewport_offset = rolling_area.global_position

	for socket_ui in socket_container.get_children():
		var rect = socket_ui.get_global_rect()
		var screen_pos = rect.get_center()
		
		# ★ 좌표 보정: 전체 화면 좌표에서 뷰포트 시작 위치를 빼서 '뷰포트 내부 좌표'로 변환
		var local_viewport_pos = screen_pos - viewport_offset
		
		# 변환된 좌표로 레이캐스팅 수행
		var ray_origin = camera.project_ray_origin(local_viewport_pos)
		var ray_normal = camera.project_ray_normal(local_viewport_pos)

		if ray_normal.y < -0.001:
			var t = (ray_origin.y - plane_y) / -ray_normal.y
			var world_pos = ray_origin + ray_normal * t
			socket_positions.append(world_pos)
		else:
			socket_positions.append(Vector3.ZERO)
			
	# 이미 투자된 주사위들의 위치도 즉시 동기화 (화면 크기 변경 대응)
	for i in range(invested_dice_nodes.size()):
		if i < socket_positions.size():
			var dice = invested_dice_nodes[i]
			if is_instance_valid(dice):
				dice.global_position = socket_positions[i]
				
func _setup_sockets():
	# 1. 2D 소켓 UI 생성
	for i in range(MAX_INVESTED_DICE):
		var socket_ui = TextureRect.new()
		socket_ui.texture = SocketTexture
		socket_ui.custom_minimum_size = Vector2(80, 80)
		socket_ui.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		socket_ui.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		socket_container.add_child(socket_ui)

	# 2. UI가 안정화될 때까지 대기
	await get_tree().process_frame
	await get_tree().process_frame

	# 3. 안정된 2D UI 위치를 기반으로 3D 좌표 계산
	var camera = rolling_world.get_node("Camera3D")
	if not camera:
		push_error("Socket setup failed: Camera not found.")
		return
		
	var plane_y = 0.5 # 주사위가 바닥에 살짝 떠 있도록 높이 설정
	for socket_ui in socket_container.get_children():
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
	cup.scale = Vector3(1.3, 1.3, 1.3)
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
	input_manager.roll_started.connect(_on_roll_started)
	game_manager.roll_finished.connect(_on_roll_finished)
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)
	submit_button.pressed.connect(_on_submit_pressed)
	invest_button.pressed.connect(_on_invest_pressed)
	turn_end_button.pressed.connect(_on_turn_end_pressed)
	view_dice_bag_button.pressed.connect(_on_view_dice_bag_pressed)
	rolling_area.gui_input.connect(_on_rolling_area_gui_input)
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
	game_manager.check_if_all_dice_finished(dice_spawner.get_dice_count())

func _on_submit_pressed() -> void:
	var all_selected_nodes = []
	var roll_results_for_submission = {}

	var selected_3d_nodes = combo_select.get_selected_nodes()
	all_selected_nodes.append_array(selected_3d_nodes)
	var current_roll_results = game_manager.get_roll_results()
	
	for node in selected_3d_nodes:
		# 1. 현재 턴의 결과에서 찾기
		if current_roll_results.has(node.name):
			roll_results_for_submission[node.name] = current_roll_results[node.name]
		# 2. 투자된 주사위라면 저장된 meta 데이터에서 찾기
		elif node.has_meta("value"):
			roll_results_for_submission[node.name] = node.get_meta("value")
		else:
			print("오류: 주사위 값을 찾을 수 없습니다 -> ", node.name)
			return # 값을 모르면 계산 불가
	if all_selected_nodes.is_empty():
		print("조합을 제출하려면 먼저 주사위를 선택하세요.")
		return

	if score_manager.evaluate_and_score_combo(all_selected_nodes, roll_results_for_submission):
		_remove_combo_dice(selected_3d_nodes)
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
	var nodes_to_invest = combo_select.pop_selected_nodes() 
	if nodes_to_invest.is_empty():
		print("투자할 주사위를 먼저 선택하세요.")
		return
	if invested_dice_nodes.size() + nodes_to_invest.size() > MAX_INVESTED_DICE:
		print("최대 %d개까지만 투자할 수 있습니다." % MAX_INVESTED_DICE)
		return

	_invest_dice(nodes_to_invest)
	combo_select.exit()
	Main.invests_left -= 1
	_update_ui_from_gamestate()
	
	
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
	else:
		print("No more turns left.")

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
