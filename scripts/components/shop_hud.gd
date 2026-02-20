extends Control
class_name ShopHUD
signal go_to_game_requested
signal joker_purchased

# Scene Resources
@export var shop_dice_scene: PackedScene
const CupScene = preload("res://cup.tscn")
const GameConstants = preload("res://scripts/utils/constants.gd")

# UI Node References
@onready var next_round_button: Button = $MainLayout/GameArea/ShopHeader/NextRoundButton
@onready var reroll_button: Button = $MainLayout/GameArea/ShopHeader/RerollButton
@onready var gold_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/GoldLabel
@onready var joker_inventory: HBoxContainer = $MainLayout/InfoPanel/Panel/VBoxContainer/JokerInventory
@onready var buy_panel: PanelContainer = $MainLayout/GameArea/BuyPanel

# 3D Node References
@onready var shop_area = $"../../3D_World/ShopArea"

# Shop State
enum ShopMode { NONE, JOKER, DICE }
var current_mode = ShopMode.NONE

var cup: Node3D
var current_shop_dice = []
var is_shaking = false
var finished_dice_count = 0
var available_jokers_to_buy = []
var available_dice_to_buy = [] # [추가] 구매 가능한 주사위 목록

@onready var selection_panel = $MainLayout/GameArea/SelectionPanel # [추가] 선택 패널
@onready var shop_header = $MainLayout/GameArea/ShopHeader # [추가] 헤더 참조
@onready var dice_options = $MainLayout/GameArea/BuyPanel/VBoxContainer/DiceOptions # [수정] 경로 변경
@onready var joker_options = $MainLayout/GameArea/BuyPanel/VBoxContainer/JokerOptions # [추가] 경로 변경

func _ready() -> void:
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	reroll_button.pressed.connect(enter_shop_sequence)
	
	# [추가] 선택 버튼 연결
	$MainLayout/GameArea/SelectionPanel/BuyJokerButton.pressed.connect(_on_buy_joker_mode_selected)
	$MainLayout/GameArea/SelectionPanel/BuyDiceButton.pressed.connect(_on_buy_dice_mode_selected)
	
	# 조커 구매 버튼
	$MainLayout/GameArea/BuyPanel/VBoxContainer/JokerOptions/Option1/BuyButton1.pressed.connect(func(): _on_buy_item_pressed(0))
	$MainLayout/GameArea/BuyPanel/VBoxContainer/JokerOptions/Option2/BuyButton2.pressed.connect(func(): _on_buy_item_pressed(1))
	$MainLayout/GameArea/BuyPanel/VBoxContainer/JokerOptions/Option3/BuyButton3.pressed.connect(func(): _on_buy_item_pressed(2))

	# [추가] 주사위 구매 버튼
	$MainLayout/GameArea/BuyPanel/VBoxContainer/DiceOptions/Option1/BuyButton1.pressed.connect(func(): _on_buy_item_pressed(0))
	$MainLayout/GameArea/BuyPanel/VBoxContainer/DiceOptions/Option2/BuyButton2.pressed.connect(func(): _on_buy_item_pressed(1))
	$MainLayout/GameArea/BuyPanel/VBoxContainer/DiceOptions/Option3/BuyButton3.pressed.connect(func(): _on_buy_item_pressed(2))

func _gui_input(event: InputEvent) -> void:
	if current_mode != ShopMode.JOKER: return # 조커 모드일 때만 드래그/굴리기 허용
	
	# A die is rolling if its internal state machine is active.
	var a_die_is_rolling = false
	for dice in current_shop_dice:
		if dice.rolling:
			a_die_is_rolling = true
			break
			
	if a_die_is_rolling or buy_panel.visible: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_shaking()
		else:
			if is_shaking:
				_release_and_pour()

func enter_shop_sequence() -> void:
	_update_gold_label()
	joker_inventory.update_display(Main.owned_jokers)
	clear_shop_objects()
	
	current_mode = ShopMode.NONE
	selection_panel.visible = true
	shop_header.visible = false
	buy_panel.visible = false
	
	is_shaking = false
	finished_dice_count = 0

func _on_buy_joker_mode_selected():
	selection_panel.visible = false
	shop_header.visible = true
	current_mode = ShopMode.JOKER
	_setup_shop_scene()

func _on_buy_dice_mode_selected():
	selection_panel.visible = false
	shop_header.visible = true
	current_mode = ShopMode.DICE
	_setup_dice_shop_scene()

func _setup_dice_shop_scene():
	# 주사위 구매는 굴리기 없이 바로 목록 보여줌 (원하는 경우 굴리기 추가 가능)
	var available_types = []
	for i in range(1, 9): # 1~8번 주사위 대상
		if not Main.owned_dice_types.has(i):
			available_types.append(i)
	
	available_types.shuffle()
	available_dice_to_buy = available_types.slice(0, 3)
	
	display_purchase_options([], available_dice_to_buy)

func _setup_shop_scene():
	cup = CupScene.instantiate()
	# 상점 트레이 중앙(60, 0, 0)에 맞추기 위해 로컬 (0, 10, 0) 사용
	cup.position = Vector3(0, 10, 0) 
	shop_area.add_child(cup)
	
	# [추가] 물리 및 애니메이션 초기화
	await get_tree().process_frame
	if is_instance_valid(cup):
		cup.update_initial_transform()
		if cup.has_method("_set_ceiling_collision"):
			cup._set_ceiling_collision(true)
			
	spawn_shop_dice(3)

func clear_shop_objects():
	for dice in current_shop_dice:
		if is_instance_valid(dice):
			dice.queue_free()
	current_shop_dice.clear()
	
	if is_instance_valid(cup):
		cup.queue_free()
		cup = null
	
	if buy_panel: buy_panel.visible = false

func spawn_shop_dice(count: int):
	if not shop_dice_scene:
		push_error("ShopDice scene is not set in the inspector!")
		return
	if not is_instance_valid(cup):
		push_error("Cup is not valid during spawn_shop_dice!")
		return

	# [변경] 상점 주사위도 3D 월드에 직접 추가 (shop_area의 부모인 3D_World 사용)
	var world_node = shop_area.get_parent()
	if not world_node:
		push_error("Could not find 3D_World node!")
		return

	# 스폰 시에는 주사위가 컵 안에 갇히도록 천장 충돌 활성화
	if cup.has_method("_set_ceiling_collision"):
		cup._set_ceiling_collision(true)

	for i in range(count):
		var dice = shop_dice_scene.instantiate() as ShopDice
		world_node.add_child(dice)
		current_shop_dice.append(dice)
		
		# Connect to the die's own finish signal
		dice.roll_finished.connect(_on_shop_dice_roll_finished)
		
		# 컵 내부로 소환 (Y축 오프셋을 살짝 줘서 겹침 방지)
		var offset = Vector3(
			randf_range(-0.5, 0.5), 
			randf_range(0.5, 1.5), 
			randf_range(-0.5, 0.5)
		)
		dice.global_position = cup.global_position + offset
		
		var random_jokers = JokerManager.get_random_jokers(6)
		if random_jokers == null or random_jokers.size() < 6:
			dice.queue_free()
			current_shop_dice.pop_back()
			continue
			
		dice.setup_jokers(random_jokers)
		dice.setup_physics_for_spawning()

func _start_shaking():
	if not is_instance_valid(cup): return
	is_shaking = true
	if cup.has_method("start_shaking"):
		cup.start_shaking()

func _release_and_pour() -> void:
	if not is_instance_valid(cup): return
	
	is_shaking = false
	
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	if cup.has_method("pour"):
		await cup.pour()
	if cup.has_method("_set_ceiling_collision"):
		cup._set_ceiling_collision(false)
	
	for dice in current_shop_dice:
		dice.apply_outside_cup_physics()
		
		# [변경] GameConstants를 사용하여 게임 플레이와 동일한 물리 적용
		var impulse = Vector3(
			randf_range(GameConstants.DICE_IMPULSE_RANGE.x, GameConstants.DICE_IMPULSE_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Y_RANGE.x, GameConstants.DICE_IMPULSE_Y_RANGE.y),
			randf_range(GameConstants.DICE_IMPULSE_Z_RANGE.x, GameConstants.DICE_IMPULSE_Z_RANGE.y)
		)

		var torque = Vector3(
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y),
			randf_range(GameConstants.DICE_TORQUE_RANGE.x, GameConstants.DICE_TORQUE_RANGE.y)
		)

		dice.apply_impulse_force(impulse, torque)
		dice.start_rolling() # Activate the internal state machine

func _on_shop_dice_roll_finished(value: int, dice_name: String):
	finished_dice_count += 1
	if finished_dice_count == current_shop_dice.size():
		_align_and_present_results()

func _align_and_present_results() -> void:
	var available_jokers = []
	for dice in current_shop_dice:
		var top_joker = dice.get_top_joker()
		if top_joker:
			available_jokers.append(top_joker)
	
	if available_jokers.size() != current_shop_dice.size():
		display_purchase_options(available_jokers, [])
		return

	var tweens = []
	var center_x = shop_area.global_position.x
	var start_x = center_x - (current_shop_dice.size() - 1) * (GameConstants.DICE_SPACING / 2.0)
	
	# 1. Prepare all dice for tweening
	for i in range(current_shop_dice.size()):
		var dice = current_shop_dice[i]
		var top_joker_for_alignment = available_jokers[i]

		# Set rotation first and wait for it to apply
		if top_joker_for_alignment:
			await dice.align_to_top_joker(top_joker_for_alignment)

		# Disable the parent's physics process to prevent interference
		dice.set_physics_process(false)
		# Set to kinematic to allow tweening without physics interference
		dice.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		# Stop all movement
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO
		# Disable collision to prevent them from hitting each other during the tween
		dice.set_collision_enabled(false)

	# 2. Create and run tweens for each die
	for i in range(current_shop_dice.size()):
		var dice = current_shop_dice[i]
		
		var target_pos = Vector3(start_x + i * GameConstants.DICE_SPACING, shop_area.global_position.y + GameConstants.DISPLAY_Y, shop_area.global_position.z)
		var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(dice, "global_position", target_pos, GameConstants.MOVE_DURATION)
		tweens.append(tween)

	# 3. Wait for all tweens to finish
	for tween in tweens:
		await tween.finished
	
	# 4. Re-enable collision and physics process now that they are in place
	for dice in current_shop_dice:
		if is_instance_valid(dice):
			dice.set_collision_enabled(true)
			dice.set_physics_process(true)
		
	# 5. Now display the UI
	display_purchase_options(available_jokers, [])

func display_purchase_options(jokers: Array, dice_types: Array):
	buy_panel.visible = true
	
	if current_mode == ShopMode.JOKER:
		available_jokers_to_buy = jokers
		joker_options.visible = true
		dice_options.visible = false
		
		for i in range(3):
			var option_root = joker_options.get_child(i)
			if i < jokers.size():
				var joker = jokers[i]
				option_root.get_node("JokerName" + str(i+1)).text = joker["korean_name"]
				var buy_button = option_root.get_node("BuyButton" + str(i+1))
				buy_button.text = "Buy ($%d)" % joker["Price"]
				buy_button.disabled = Main.gold < joker["Price"]
				option_root.visible = true
			else:
				option_root.visible = false
				
	elif current_mode == ShopMode.DICE:
		available_dice_to_buy = dice_types
		joker_options.visible = false
		dice_options.visible = true
		
		for i in range(3):
			var option_root = dice_options.get_child(i)
			if i < dice_types.size():
				var type_idx = dice_types[i]
				var info = Main.ALL_DICE_INFO[type_idx]
				option_root.get_node("DiceName" + str(i+1)).text = info["name"]
				var buy_button = option_root.get_node("BuyButton" + str(i+1))
				buy_button.text = "Buy ($%d)" % info["price"]
				buy_button.disabled = Main.gold < info["price"] or Main.owned_dice_types.has(type_idx)
				option_root.visible = true
			else:
				option_root.visible = false

func _on_buy_item_pressed(index: int):
	if current_mode == ShopMode.JOKER:
		if index >= available_jokers_to_buy.size(): return
		var joker = available_jokers_to_buy[index]
		if Main.gold >= joker["Price"]:
			Main.gold -= joker["Price"]
			Main.owned_jokers.append(joker)
			emit_signal("joker_purchased")
			_on_item_purchased()
			
			var btn = joker_options.get_child(index).get_node("BuyButton" + str(index+1))
			btn.disabled = true
			btn.text = "Purchased"
			
	elif current_mode == ShopMode.DICE:
		if index >= available_dice_to_buy.size(): return
		var type_idx = available_dice_to_buy[index]
		var info = Main.ALL_DICE_INFO[type_idx]
		if Main.gold >= info["price"] and not Main.owned_dice_types.has(type_idx):
			Main.gold -= info["price"]
			Main.owned_dice_types.append(type_idx)
			_on_item_purchased()
			
			var btn = dice_options.get_child(index).get_node("BuyButton" + str(index+1))
			btn.disabled = true
			btn.text = "Purchased"

func _on_next_round_button_pressed() -> void:
	clear_shop_objects()
	StageManager.advance_to_next_round()
	emit_signal("go_to_game_requested")

func _update_gold_label() -> void:
	gold_label.text = "Gold: $%d" % Main.gold

func _on_item_purchased() -> void:
	_update_gold_label()
	joker_inventory.update_display(Main.owned_jokers)
	display_purchase_options(available_jokers_to_buy, available_dice_to_buy)
