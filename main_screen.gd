extends Control
class_name MainScreen

# === UI 노드 참조 (UI 버전에 맞게 수정됨) ===
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
@onready var invested_dice_container: HBoxContainer = $MainLayout/GameArea/FieldArea/InvestedDiceContainer

# === 3D 씬 참조 ===
var world_3d: Node3D
var game_manager: GameManager
var input_manager: InputManager
var score_manager: ScoreManager
var dice_spawner: DiceSpawner
var combo_select: ComboSelect
var cup: Node3D
var rolling_world: Node3D # RollingWorld 씬의 인스턴스

# === 리소스 로드 (병합됨) ===
const RollingWorldScene = preload("res://scenes/rolling_world.tscn")
const CupScene := preload("res://cup.tscn")
const InvestedDie3DScene = preload("res://scripts/components/invested_die_3d.tscn") # UI 버전의 3D 투자 주사위
const DiceBagPopupScene = preload("res://scripts/components/dice_bag_popup.tscn")

const MAX_INVESTED_DICE = 10

var dice_bag_popup: Window


func _ready() -> void:
	# 3D 월드 생성 (UI 버전에 맞게 수정)
	rolling_world = RollingWorldScene.instantiate()
	world_3d = rolling_world
	sub_viewport.add_child(world_3d)

	# 팝업 초기화
	dice_bag_popup = DiceBagPopupScene.instantiate()
	add_child(dice_bag_popup)

	# 초기화
	_initialize_managers()
	_setup_scene()
	_setup_game()
	_connect_signals()
	_update_ui_from_gamestate()
	
	# 뷰포트 크기 초기화 (UI 버전에 맞게 추가)
	_on_rolling_area_resized()

func _initialize_managers() -> void:
	# 에셋 버전의 Manager들을 그대로 사용
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
	# 에셋 버전의 컵 생성 로직 사용
	cup = CupScene.instantiate()
	cup.position = GameConstants.CUP_POSITION
	world_3d.add_child(cup)

func _setup_game() -> void:
	game_manager.initialize()
	game_manager.setup_cup(cup)
	# rolling_world에서 카메라를 가져오도록 수정
	input_manager.initialize(combo_select, rolling_world.get_node("Camera3D")) 
	# dice_spawner 초기화 시 runtime_container 대신 world_3d를 넘겨줌
	dice_spawner.initialize(cup, world_3d)
	_invest_initial_dice()
	_spawn_initial_dice()

# UI 버전의 3D 투자 주사위 표시 로직과 에셋 버전의 주사위 생성 로직을 병합
func _invest_initial_dice() -> void:
	if not game_manager.can_draw_dice(5):
		push_error("Not enough dice in bag for initial investment")
		return

	var dice_colors = dice_spawner.create_dice_colors_from_bag(game_manager.bag, 5)

	for i in range(dice_colors.size()):
		var color = dice_colors[i]
		var value = randi_range(1, 6)
		
		# --- Create the 3D display UI (새로운 방식) ---
		var display = InvestedDie3DScene.instantiate()
		display.custom_minimum_size = Vector2(80, 80)
		display.name = "invested_dice_init_" + str(i)
		
		# 값을 설정하고, 색상 enum을 설정합니다.
		display.value = value
		display.dice_color_enum = ColoredDice.color_from_godot_color(color)
		
		invested_dice_container.add_child(display)

func _spawn_initial_dice() -> void:
	# 에셋 버전 로직 그대로 사용
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
	# 두 버전 공통 시그널 연결
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
	# UI 버전에만 있던 resized 시그널 연결 추가
	rolling_area.resized.connect(_on_rolling_area_resized)

func _update_ui_from_gamestate() -> void:
	update_stage(Main.stage)
	update_target_score(Main.target_score)
	update_current_score(Main.current_score)
	update_turns_left(Main.turns_left)
	update_invests_left(Main.invests_left)

# UI 버전에만 있던 함수 추가
func _on_rolling_area_resized() -> void:
	var viewport_size = rolling_area.size
	sub_viewport.size = viewport_size

	if rolling_world and rolling_world.has_method("update_size"):
		rolling_world.update_size(viewport_size)

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
	var original_roll_results = game_manager.get_roll_results()
	for node in selected_3d_nodes:
		roll_results_for_submission[node.name] = original_roll_results[node.name]

	var selected_invested_nodes = []
	for node in invested_dice_container.get_children():
		if node.has_method("is_selected") and node.is_selected():
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

# UI 버전의 3D 투자 주사위 표시 로직과 에셋 버전의 주사위 생성 로직을 병합
const AnimatedSpriteTexture = preload("res://icon.png") # 애니메이션용 임시 텍스처

# ... (다른 코드들은 그대로) ...

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

	if invested_dice_container.get_child_count() + nodes_to_invest.size() > MAX_INVESTED_DICE:
		print("최대 %d개까지만 투자할 수 있습니다." % MAX_INVESTED_DICE)
		# 롤백 로직이 필요하지만, 일단은 경고만 출력
		return

	# _invest_dice를 직접 호출하는 대신 애니메이션 함수를 호출합니다.
	_animate_investment(nodes_to_invest)
	
	combo_select.exit()
	Main.invests_left -= 1
	_update_ui_from_gamestate()

func _animate_investment(nodes: Array):
	var camera = rolling_world.get_node("Camera3D")
	if not camera:
		push_error("Animation failed: Camera not found.")
		# 애니메이션 없이 즉시 투자 실행
		_invest_dice_fallback(nodes)
		return

	var roll_results = game_manager.get_roll_results()
	
	# 투자 슬롯의 다음 빈 위치를 찾습니다.
	var start_slot_index = invested_dice_container.get_child_count()

	for i in range(nodes.size()):
		var dice_node = nodes[i]
		if not roll_results.has(dice_node.name): continue
		
		# 1. 애니메이션 시작/끝 위치 계산
		var start_pos_3d = dice_node.global_position
		var start_pos_2d = camera.unproject_position(start_pos_3d)
		
		# 임시 투자 슬롯을 만들어 목표 위치를 계산합니다.
		var temp_slot = Control.new()
		temp_slot.custom_minimum_size = Vector2(80, 80)
		invested_dice_container.add_child(temp_slot)
		await get_tree().process_frame # 컨테이너가 크기를 계산할 시간을 줍니다.
		var end_pos_2d = temp_slot.get_global_position()
		temp_slot.queue_free() # 위치 계산 후 임시 슬롯 제거

		# 2. 애니메이션용 2D 스프라이트 생성
		var anim_sprite = TextureRect.new()
		anim_sprite.texture = AnimatedSpriteTexture
		anim_sprite.custom_minimum_size = Vector2(50, 50)
		anim_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		anim_sprite.position = start_pos_2d - anim_sprite.custom_minimum_size / 2
		add_child(anim_sprite) # 메인 캔버스에 추가

		# 3. 원래 3D 주사위 숨기기
		dice_node.visible = false

		# 4. Tween으로 애니메이션 실행
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(anim_sprite, "position", end_pos_2d, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(anim_sprite, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# 5. 애니메이션 완료 후 콜백 연결
		tween.finished.connect(
			_on_investment_animation_finished.bind(anim_sprite, dice_node, roll_results[dice_node.name])
		)

	# 투자된 주사위는 더 이상 굴릴 수 없으므로 spawner와 game_manager에서 제거
	_remove_combo_dice(nodes)


func _on_investment_animation_finished(sprite: TextureRect, original_dice_node: Node3D, value: int):
	# 애니메이션 스프라이트 제거
	sprite.queue_free()
	
	# 이제 진짜 InvestedDie3D 인스턴스를 생성하고 배치합니다.
	var display = InvestedDie3DScene.instantiate()
	display.custom_minimum_size = Vector2(80, 80)
	display.name = "invested_dice_" + str(display.get_instance_id())
	
	display.value = value
	display.dice_color_enum = original_dice_node.current_dice_color
	
	invested_dice_container.add_child(display)
	
	# 숨겼던 원래 3D 주사위 노드를 완전히 제거합니다.
	original_dice_node.queue_free()

# 애니메이션을 실행할 수 없을 때를 위한 대체 함수
func _invest_dice_fallback(nodes: Array):
	var roll_results = game_manager.get_roll_results()
	for dice_node in nodes:
		if not roll_results.has(dice_node.name): continue
		var value = roll_results[dice_node.name]
		
		var display = InvestedDie3DScene.instantiate()
		display.custom_minimum_size = Vector2(80, 80)
		display.name = "invested_dice_" + str(display.get_instance_id())
		
		display.value = value
		display.dice_color_enum = dice_node.current_dice_color
		
		invested_dice_container.add_child(display)

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

func _on_view_dice_bag_pressed() -> void:
	dice_bag_popup.update_counts(game_manager.bag)
	dice_bag_popup.show()

# --- Public API (두 버전이 동일) ---
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