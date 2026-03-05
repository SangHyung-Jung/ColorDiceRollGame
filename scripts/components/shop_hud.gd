extends Control
class_name ShopHUD
signal go_to_game_requested
signal joker_purchased

# Scene Resources
@export var shop_dice_scene: PackedScene
const CupScene = preload("res://cup.tscn")
const GameConstants = preload("res://scripts/utils/constants.gd")

# UI Node References
@onready var reroll_button: Button = $MainLayout/ContentArea/BottomControls/NavRow/RerollButton
@onready var next_round_button: Button = $MainLayout/ContentArea/BottomControls/NavRow/NextRoundButton
@onready var random_items_container: HBoxContainer = %RandomItems
@onready var joker_category_button: Button = %JokerButton
@onready var special_dice_category_button: Button = %SpecialDiceButton
@onready var item_category_button: Button = %ItemButton

var side_panel: PersistentSidePanel

# 3D Node References
@onready var shop_area = $"../../3D_World/ShopArea"

# Shop State
enum ShopMode { NONE, JOKER, DICE, ITEM }
var current_mode = ShopMode.NONE

var cup: Node3D
var current_shop_dice = []
var is_shaking = false
var finished_dice_count = 0
var _is_aligning = false
var available_shop_items = [] 

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	joker_category_button.pressed.connect(_on_buy_joker_mode_selected)
	enter_shop_sequence()

func enter_shop_sequence() -> void:
	if side_panel:
		side_panel.show_shop_ui()
		side_panel.update_stage_text("LOUNGE")
		side_panel.update_joker_inventory(Main.owned_jokers)
		side_panel.update_gold(Main.gold)

	clear_shop_objects()
	current_mode = ShopMode.NONE
	_refresh_random_items()
	
	is_shaking = false
	finished_dice_count = 0
	_setup_cup_with_animation()

func _setup_cup_with_animation():
	if is_instance_valid(cup): cup.queue_free()
	
	cup = CupScene.instantiate()
	shop_area.add_child(cup)
	
	# [수정] 하단 UI 짤림 방지를 위해 Z축을 -4로 설정 (화면 위쪽으로 이동)
	# X=0은 상점 카메라 중앙(60)에 해당함
	var target_pos = Vector3(0, 10, -4) 
	cup.position = target_pos + Vector3(-15, 0, 0) # 왼쪽에서 등장
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cup, "position", target_pos, 1.0)
	
	await tween.finished
	cup.update_initial_transform()
	if cup.has_method("_set_ceiling_collision"):
		cup._set_ceiling_collision(true)

# [GameRoot 연동] Cup.gd의 shaking 로직 그대로 사용
func start_shaking_sequence():
	if current_mode == ShopMode.NONE or not is_instance_valid(cup): return
	
	var a_die_is_rolling = false
	for dice in current_shop_dice:
		if is_instance_valid(dice) and dice.rolling:
			a_die_is_rolling = true; break
	if a_die_is_rolling: return
	
	is_shaking = true
	if cup.has_method("start_shaking"):
		cup.start_shaking()

func stop_shaking_sequence():
	if not is_shaking or not is_instance_valid(cup): return
	is_shaking = false
	
	if cup.has_method("stop_shaking"): 
		await cup.stop_shaking()
	
	for dice in current_shop_dice:
		if is_instance_valid(dice):
			dice.apply_outside_cup_physics()
			var impulse = Vector3(
				randf_range(GameConstants.DICE_IMPULSE_RANGE.x, GameConstants.DICE_IMPULSE_RANGE.y),
				randf_range(GameConstants.DICE_IMPULSE_Y_RANGE.x, GameConstants.DICE_IMPULSE_Y_RANGE.y),
				randf_range(GameConstants.DICE_IMPULSE_Z_RANGE.x, GameConstants.DICE_IMPULSE_Z_RANGE.y)
			)
			var torque = Vector3(randf_range(-40, 40), randf_range(-40, 40), randf_range(-40, 40))
			dice.apply_impulse_force(impulse, torque)
			dice.start_rolling()

	if cup.has_method("pour"): 
		await cup.pour()
	
	if cup.has_method("_set_ceiling_collision"): 
		cup._set_ceiling_collision(false)

func spawn_shop_dice(count: int):
	if not is_instance_valid(cup): return
	
	var world_node = shop_area.get_parent() 
	for i in range(count):
		var dice = shop_dice_scene.instantiate() as ShopDice
		world_node.add_child(dice)
		current_shop_dice.append(dice)
		dice.roll_finished.connect(_on_shop_dice_roll_finished)
		
		# [수정] 컵의 글로벌 위치를 실시간으로 가져와 바로 위에서 투하
		# 오차 범위를 줄이기 위해 offset을 더 좁게(0.1) 설정
		var cup_global_pos = cup.global_transform.origin
		var spawn_height = 6.0 # 컵 입구 높이 고려
		var offset = Vector3(randf_range(-0.1, 0.1), spawn_height + (i * 1.2), randf_range(-0.1, 0.1))
		dice.global_position = cup_global_pos + offset
		
		var random_jokers = JokerManager.get_random_jokers(6)
		dice.setup_jokers(random_jokers)
		dice.setup_physics_for_spawning()

func _on_buy_joker_mode_selected():
	for d in current_shop_dice: if is_instance_valid(d): d.queue_free()
	current_shop_dice.clear()
	current_mode = ShopMode.JOKER
	finished_dice_count = 0
	_is_aligning = false
	if is_instance_valid(cup):
		if cup.has_method("_set_ceiling_collision"): cup._set_ceiling_collision(true)
		spawn_shop_dice(3)

func _on_reroll_pressed():
	if Main.gold >= 2:
		Main.gold -= 2
		enter_shop_sequence()

func _refresh_random_items():
	available_shop_items.clear()
	var slots = random_items_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		var item_type = "joker" if randf() > 0.4 else "dice"
		var item_data = {}
		var price = 0
		if item_type == "joker":
			var jokers = JokerManager.get_random_jokers(1)
			if jokers.is_empty(): continue
			item_data = jokers[0]; price = item_data["Price"]
			slot.get_node("VBox/Name").text = item_data["korean_name"]
		else:
			var unowned = []
			for type_idx in range(1, 9):
				if not Main.owned_dice_types.has(type_idx): unowned.append(type_idx)
			if unowned.is_empty():
				var jokers = JokerManager.get_random_jokers(1)
				item_data = jokers[0]; item_type = "joker"; price = item_data["Price"]
				slot.get_node("VBox/Name").text = item_data["korean_name"]
			else:
				var dice_idx = unowned[randi() % unowned.size()]
				item_data = Main.ALL_DICE_INFO[dice_idx]; item_data["type_index"] = dice_idx
				price = 6; slot.get_node("VBox/Name").text = item_data["name"]
		var buy_btn = slot.get_node("VBox/BuyButton")
		buy_btn.text = "Buy $%d" % price; buy_btn.disabled = Main.gold < price
		for conn in buy_btn.pressed.get_connections(): buy_btn.pressed.disconnect(conn.callable)
		buy_btn.pressed.connect(_on_random_item_buy_pressed.bind(i))
		available_shop_items.append({"type": item_type, "data": item_data, "price": price})

func _on_random_item_buy_pressed(index: int):
	var item = available_shop_items[index]
	if Main.gold >= item.price:
		Main.gold -= item.price
		if item.type == "joker": Main.owned_jokers.append(item.data); emit_signal("joker_purchased")
		else: Main.owned_dice_types.append(item.data.type_index)
		if side_panel: side_panel.update_gold(Main.gold); side_panel.update_joker_inventory(Main.owned_jokers)
		var slot = random_items_container.get_child(index)
		slot.get_node("VBox/BuyButton").disabled = true; slot.get_node("VBox/BuyButton").text = "SOLDOUT"

func clear_shop_objects():
	for dice in current_shop_dice: if is_instance_valid(dice): dice.queue_free()
	current_shop_dice.clear()
	if is_instance_valid(cup): cup.queue_free(); cup = null

func _on_shop_dice_roll_finished(_v, _n):
	finished_dice_count += 1
	if finished_dice_count >= current_shop_dice.size():
		if not _is_aligning:
			_is_aligning = true
			await get_tree().create_timer(0.4).timeout
			_align_and_present_results()

func _align_and_present_results():
	var final_joker_data = []; var target_rotations = []
	for dice in current_shop_dice:
		if is_instance_valid(dice):
			var face_idx = dice.get_top_face_index()
			final_joker_data.append(dice.assigned_jokers[face_idx])
			var face_val = ShopDice.JOKER_FACE_TO_DICE_FACE_MAP[face_idx]
			var target_rot = dice._get_rotation_for_face(face_val); target_rot.y = 0 
			target_rotations.append(target_rot)
	var center_x = shop_area.global_position.x
	var start_x = center_x - (current_shop_dice.size() - 1) * (GameConstants.DICE_SPACING / 2.0)
	var master_tween = create_tween().set_parallel()
	for i in range(current_shop_dice.size()):
		var dice = current_shop_dice[i]
		if is_instance_valid(dice):
			dice.freeze = true; dice.set_collision_enabled(false)
			var target_pos = Vector3(start_x + i * GameConstants.DICE_SPACING, shop_area.global_position.y + 2.0, shop_area.global_position.z)
			var target_quat = Quaternion.from_euler(Vector3(deg_to_rad(target_rotations[i].x), 0, deg_to_rad(target_rotations[i].z)))
			master_tween.tween_property(dice, "global_position", target_pos, GameConstants.MOVE_DURATION)
			master_tween.tween_property(dice, "quaternion", target_quat, GameConstants.MOVE_DURATION)

func _on_next_round_button_pressed():
	clear_shop_objects()
	StageManager.advance_to_next_round()
	emit_signal("go_to_game_requested")
