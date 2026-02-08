extends Control
class_name ShopHUD
signal go_to_game_requested
signal joker_purchased

# Scene Resources
@export var shop_dice_scene: PackedScene

# UI Node References
@onready var next_round_button: Button = $MainLayout/GameArea/ShopHeader/NextRoundButton
@onready var reroll_button: Button = $MainLayout/GameArea/ShopHeader/RerollButton
@onready var gold_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/GoldLabel
@onready var joker_inventory: HBoxContainer = $MainLayout/InfoPanel/Panel/VBoxContainer/JokerInventory
@onready var roll_button: Button = $MainLayout/GameArea/RollButton
@onready var buy_panel: PanelContainer = $MainLayout/GameArea/BuyPanel

# 3D Node References
@onready var dice_spawn_point = $"../../3D_World/ShopArea/SpawnPoint"

# Shop State
var current_shop_dice = []
var is_rolling = false
var available_jokers_to_buy = []


func _ready() -> void:
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	roll_button.pressed.connect(roll_dice)
	reroll_button.pressed.connect(enter_shop_sequence)
	
	# Connect buy buttons
	$MainLayout/GameArea/BuyPanel/JokerOptions/Option1/BuyButton1.pressed.connect(func(): _on_buy_joker_pressed(0))
	$MainLayout/GameArea/BuyPanel/JokerOptions/Option2/BuyButton2.pressed.connect(func(): _on_buy_joker_pressed(1))
	$MainLayout/GameArea/BuyPanel/JokerOptions/Option3/BuyButton3.pressed.connect(func(): _on_buy_joker_pressed(2))


func enter_shop_sequence() -> void:
	# This function will be called by GameRoot when transitioning to shop
	_update_gold_label()
	joker_inventory.update_display(Main.owned_jokers)
	
	# 1. 기존 주사위 제거
	clear_shop_dice()
	
	# 2. 새 주사위 3개 생성
	spawn_shop_dice(3)
	
	# 3. 굴리기 시작 버튼 활성화 등 UI 처리
	roll_button.visible = true
	buy_panel.visible = false

func clear_shop_dice():
	for dice in current_shop_dice:
		if is_instance_valid(dice):
			dice.queue_free()
	current_shop_dice.clear()

func spawn_shop_dice(count: int):
	if not shop_dice_scene:
		push_error("ShopDice scene is not set in the inspector!")
		return
		
	for i in range(count):
		var dice = shop_dice_scene.instantiate() as ShopDice
		
		# GameRoot의 3D_World에 추가해야 물리 효과 적용됨
		var world_node = get_tree().root.get_node("GameRoot/3D_World")
		if not world_node:
			dice.queue_free()
			continue

		# Add to tree BEFORE calling setup, so @onready vars are initialized.
		world_node.add_child(dice)
		current_shop_dice.append(dice)
		
		# 랜덤 위치 약간 섞어서 생성
		var offset = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		dice.position = dice_spawn_point.global_position + offset
		
		# 조커 데이터 6개 뽑아서 주사위에 주입
		var random_jokers = JokerManager.get_random_jokers(6)
		if random_jokers == null or random_jokers.size() < 6:
			push_error("Not enough jokers in JokerManager to create a shop dice!")
			dice.queue_free() # Already in tree, so queue_free is correct
			current_shop_dice.pop_back() # Remove from our array
			continue
			
		dice.setup_jokers(random_jokers)
		dice.freeze = true

func roll_dice():
	if not shop_dice_scene:
		roll_button.text = "Assign Scene!"
		push_error("ShopDice scene is not set in the inspector!")
		return
	if is_rolling: return
	
	is_rolling = true
	roll_button.disabled = true
	
	for dice in current_shop_dice:
		dice.freeze = false
		dice.sleeping = false # Wake up the dice
		# 무작위 힘과 회전력 가하기
		var force = Vector3(randf_range(-1, 1), 5, randf_range(-1, 1)).normalized()
		dice.apply_central_impulse(force * randf_range(8, 12))
		dice.apply_torque(Vector3(randf(), randf(), randf()).normalized() * randf_range(20, 40))

func _process(delta):
	if is_rolling:
		check_dice_stopped()

func check_dice_stopped():
	if current_shop_dice.is_empty():
		is_rolling = false
		return

	var all_stopped = true
	for dice in current_shop_dice:
		if dice.sleeping == false:
			all_stopped = false
			break
	
	if all_stopped:
		is_rolling = false
		roll_button.disabled = false
		on_roll_finished()

func on_roll_finished():
	# 결과 확인 및 구매 UI 표시
	var available_jokers = []
	for dice in current_shop_dice:
		var top_joker = dice.get_top_joker()
		if top_joker:
			available_jokers.append(top_joker)
	
	display_purchase_options(available_jokers)

func display_purchase_options(jokers: Array):
	available_jokers_to_buy = jokers
	buy_panel.visible = true
	
	for i in range(3):
		var option_root = $MainLayout/GameArea/BuyPanel/JokerOptions.get_child(i)
		var name_label = option_root.get_node("JokerName" + str(i+1))
		var buy_button = option_root.get_node("BuyButton" + str(i+1))

		if i < jokers.size():
			var joker = jokers[i]
			name_label.text = joker["korean_name"]
			buy_button.text = "Buy ($%d)" % joker["Price"]
			buy_button.disabled = Main.gold < joker["Price"]
			option_root.visible = true
		else:
			option_root.visible = false

func _on_buy_joker_pressed(index: int):
	if index >= available_jokers_to_buy.size():
		return
	
	var joker_to_buy = available_jokers_to_buy[index]
	var price = joker_to_buy["Price"]
	
	if Main.gold >= price:
		Main.gold -= price
		Main.owned_jokers.append(joker_to_buy)
		emit_signal("joker_purchased")
		_on_item_purchased()
		
		# Disable button after purchase
		var buy_button = $MainLayout/GameArea/BuyPanel/JokerOptions.get_child(index).get_node("BuyButton" + str(index+1))
		buy_button.disabled = true
		buy_button.text = "Purchased"

## '다음 라운드' 버튼을 누르면 다음 라운드 상태로 설정하고 메인 게임 화면으로 돌아갑니다.
func _on_next_round_button_pressed() -> void:
	StageManager.advance_to_next_round()
	emit_signal("go_to_game_requested")

## 골드 UI를 업데이트합니다.
func _update_gold_label() -> void:
	gold_label.text = "Gold: $%d" % Main.gold

## 아이템 구매 시 호출될 함수
func _on_item_purchased() -> void:
	# Update gold and joker displays
	_update_gold_label()
	joker_inventory.update_display(Main.owned_jokers)
	
	# Re-evaluate buy button states
	display_purchase_options(available_jokers_to_buy)
