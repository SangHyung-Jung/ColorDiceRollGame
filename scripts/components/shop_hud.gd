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
var cup: Node3D
var current_shop_dice = []
var is_rolling = false
var is_shaking = false
var available_jokers_to_buy = []

func _ready() -> void:
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	reroll_button.pressed.connect(enter_shop_sequence)
	
	$MainLayout/GameArea/BuyPanel/JokerOptions/Option1/BuyButton1.pressed.connect(func(): _on_buy_joker_pressed(0))
	$MainLayout/GameArea/BuyPanel/JokerOptions/Option2/BuyButton2.pressed.connect(func(): _on_buy_joker_pressed(1))
	$MainLayout/GameArea/BuyPanel/JokerOptions/Option3/BuyButton3.pressed.connect(func(): _on_buy_joker_pressed(2))

func _gui_input(event: InputEvent) -> void:
	if is_rolling or buy_panel.visible: return # Don't allow input if dice are rolling or results are shown
	
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
	_setup_shop_scene()
	buy_panel.visible = false
	is_rolling = false
	is_shaking = false

func _setup_shop_scene():
	cup = CupScene.instantiate()
	cup.position = GameConstants.CUP_POSITION
	shop_area.add_child(cup)
	spawn_shop_dice(3)

func clear_shop_objects():
	for dice in current_shop_dice:
		if is_instance_valid(dice):
			dice.queue_free()
	current_shop_dice.clear()
	
	if is_instance_valid(cup):
		cup.queue_free()
		cup = null

func spawn_shop_dice(count: int):
	if not shop_dice_scene:
		push_error("ShopDice scene is not set in the inspector!")
		return
	if not is_instance_valid(cup):
		push_error("Cup is not valid during spawn_shop_dice!")
		return

	if cup.has_method("_set_ceiling_collision"):
		cup._set_ceiling_collision(true)

	for i in range(count):
		var dice = shop_dice_scene.instantiate() as ShopDice
		var world_node = get_tree().root.get_node("GameRoot/3D_World")
		if not world_node:
			dice.queue_free()
			continue

		world_node.add_child(dice)
		current_shop_dice.append(dice)
		
		var offset = Vector3(randf_range(-0.5, 0.5), randf_range(-1.0, 1.0), randf_range(-0.5, 0.5))
		dice.global_position = cup.global_position + offset
		
		var random_jokers = JokerManager.get_random_jokers(6)
		if random_jokers == null or random_jokers.size() < 6:
			push_error("Not enough jokers in JokerManager!")
			dice.queue_free()
			current_shop_dice.pop_back()
			continue
			
		dice.setup_jokers(random_jokers)
		dice.setup_physics_for_spawning()

func _start_shaking():
	if is_rolling or not is_instance_valid(cup): return
	is_shaking = true
	if cup.has_method("start_shaking"):
		cup.start_shaking()

func _release_and_pour() -> void:
	if is_rolling or not is_instance_valid(cup): return
	
	is_rolling = true
	is_shaking = false
	
	if cup.has_method("stop_shaking"):
		await cup.stop_shaking()
	if cup.has_method("pour"):
		await cup.pour()
	if cup.has_method("_set_ceiling_collision"):
		cup._set_ceiling_collision(false)
	
	for dice in current_shop_dice:
		dice.apply_outside_cup_physics()
		
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

func _process(delta):
	if is_rolling:
		check_dice_stopped()

func check_dice_stopped():
	if current_shop_dice.is_empty():
		is_rolling = false
		return

	var all_stopped = true
	for dice in current_shop_dice:
		if not dice.sleeping:
			all_stopped = false
			break
	
	if all_stopped:
		is_rolling = false
		_align_and_present_results()

func _align_and_present_results() -> void:
	var available_jokers = []
	for dice in current_shop_dice:
		var top_joker = dice.get_top_joker()
		if top_joker:
			available_jokers.append(top_joker)
	
	if available_jokers.size() != current_shop_dice.size():
		print("Error: Could not determine top joker for all dice.")
		# Fallback to just displaying what we have
		display_purchase_options(available_jokers)
		return

	# Freeze dice and align them
	var tweens = []
	var center_x = shop_area.global_position.x
	var start_x = center_x - (current_shop_dice.size() - 1) * 1.5
	
	for i in range(current_shop_dice.size()):
		var dice = current_shop_dice[i]
		dice.freeze = true
		
		var target_pos = Vector3(start_x + i * GameConstants.DICE_SPACING, shop_area.global_position.y + GameConstants.DISPLAY_Y, shop_area.global_position.z)
		var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(dice, "global_position", target_pos, GameConstants.MOVE_DURATION)
		tweens.append(tween)

	# Wait for all tweens to finish
	for tween in tweens:
		await tween.finished
		
	# Now display the UI
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
	if index >= available_jokers_to_buy.size(): return
	var joker_to_buy = available_jokers_to_buy[index]
	var price = joker_to_buy["Price"]
	
	if Main.gold >= price:
		Main.gold -= price
		Main.owned_jokers.append(joker_to_buy)
		emit_signal("joker_purchased")
		_on_item_purchased()
		
		var buy_button = $MainLayout/GameArea/BuyPanel/JokerOptions.get_child(index).get_node("BuyButton" + str(index+1))
		buy_button.disabled = true
		buy_button.text = "Purchased"

func _on_next_round_button_pressed() -> void:
	clear_shop_objects()
	StageManager.advance_to_next_round()
	emit_signal("go_to_game_requested")

func _update_gold_label() -> void:
	gold_label.text = "Gold: $%d" % Main.gold

func _on_item_purchased() -> void:
	_update_gold_label()
	joker_inventory.update_display(Main.owned_jokers)
	display_purchase_options(available_jokers_to_buy)
