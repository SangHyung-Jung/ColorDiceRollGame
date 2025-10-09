
extends Control
class_name MainScreen

# === UI 노드 참조 ===
@onready var stage_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/StageLabel
@onready var target_score_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/TargetScoreLabel
@onready var current_score_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/CurrentScoreLabel
@onready var turns_left_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/TurnsLeftLabel
@onready var invests_left_label: Label = $HSplitContainer/InfoPanel/MarginContainer/VBoxContainer/InvestsLeftLabel
@onready var submit_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/SubmitButton
@onready var invest_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/InvestButton
@onready var turn_end_button: Button = $HSplitContainer/GameArea/InteractionUI/HBoxContainer/TurnEndButton
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
var invested_dice: Array[Node3D] = []

# === 리소스 로드 ===
const CupScene := preload("res://cup.tscn")
const DiceFaceImageScene = preload("res://scripts/components/dice_face_image.tscn")

@onready var invested_dice_container: HBoxContainer = $HSplitContainer/GameArea/FieldArea/InvestedDiceContainer

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
	_invest_initial_dice()
	_spawn_initial_dice()

func _invest_initial_dice() -> void:
	if not game_manager.can_draw_dice(5):
		push_error("Not enough dice in bag for initial investment")
		return

	var dice_defs = dice_spawner.create_dice_definitions(game_manager.bag, 5)
	var pips_texture = D6Dice.get_pips_texture()

	for def in dice_defs:
		var value = randi_range(1, 6)
		var body_color = def.color
		var pips_color = Color.WHITE
		if body_color.is_equal_approx(Color.WHITE):
			pips_color = Color.BLACK
		
		var texture = Dice.generate_dice_texture(pips_texture, body_color, pips_color)
		
		var display = DiceFaceImageScene.instantiate()
		display.name = "invested_dice_" + str(display.get_instance_id())
		invested_dice_container.add_child(display)
		display.set_face(value, texture)
		display.value = value
		display.dice_color = body_color

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
	game_manager.roll_finished.connect(_on_roll_finished)
	dice_spawner.dice_roll_finished.connect(_on_dice_roll_finished)
	
	# UI 버튼 연결
	submit_button.pressed.connect(_on_submit_pressed)
	invest_button.pressed.connect(_on_invest_pressed)
	turn_end_button.pressed.connect(_on_turn_end_pressed)

	# 3D 뷰포트 입력 연결
	rolling_area.gui_input.connect(_on_rolling_area_gui_input)

func _update_ui_from_gamestate() -> void:
	update_stage(Main.stage)
	update_target_score(Main.target_score)
	update_current_score(Main.current_score)
	update_turns_left(Main.turns_left)
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
	if game_manager.check_if_all_dice_finished(dice_spawner.get_dice_count()):
		_on_roll_finished()

func _on_submit_pressed() -> void:
	var all_selected_nodes = []
	var roll_results_for_submission = {}

	# Add 3D dice
	var selected_3d_nodes = combo_select.get_selected_nodes()
	all_selected_nodes.append_array(selected_3d_nodes)
	var original_roll_results = game_manager.get_roll_results()
	for node in selected_3d_nodes:
		roll_results_for_submission[node.name] = original_roll_results[node.name]

	# Add 2D invested dice
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

	_invest_dice(nodes_to_invest)
	Main.invests_left -= 1
	_update_ui_from_gamestate()

func _invest_dice(nodes: Array) -> void:
	var dice_to_invest = []
	var roll_results = game_manager.get_roll_results()
	for dice_node in nodes:
		if not roll_results.has(dice_node.name): continue
		var value = roll_results[dice_node.name]
		
		var mesh_instance = dice_node.get_node("DiceMesh")
		var material = mesh_instance.material_override
		var texture = material.albedo_texture

		dice_to_invest.append({"value": value, "texture": texture, "dice_color": dice_node.dice_color})

	_remove_combo_dice(nodes)

	for data in dice_to_invest:
		var display = DiceFaceImageScene.instantiate()
		display.name = "invested_dice_" + str(display.get_instance_id())
		invested_dice_container.add_child(display)
		display.set_face(data.value, data.texture)
		display.value = data.value
		display.dice_color = data.dice_color

func _on_turn_end_pressed() -> void:
	combo_select.exit()
	if Main.turns_left > 0:
		Main.turns_left -= 1
		_update_ui_from_gamestate()

		# Discard all dice remaining on the field
		var remaining_dice = dice_spawner.get_dice_nodes()
		for d in remaining_dice:
			d.queue_free()
		
		# Clear the spawner's internal lists
		dice_spawner.dice_nodes.clear()
		dice_spawner.dice_set.clear()

		# The player can now start a new roll.
	else:
		print("No more turns left.")


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
