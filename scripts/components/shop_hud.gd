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
var available_shop_items = [] # { type: "joker"|"dice", data: object, price: int }

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	joker_category_button.pressed.connect(_on_buy_joker_mode_selected)
	
	# 초기화
	enter_shop_sequence()

func _gui_input(event: InputEvent) -> void:
	# 조커 모드일 때만 드래그/굴리기 허용
	if current_mode != ShopMode.JOKER: return 
	
	var a_die_is_rolling = false
	for dice in current_shop_dice:
		if dice.rolling:
			a_die_is_rolling = true
			break
			
	if a_die_is_rolling: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_shaking()
		else:
			if is_shaking:
				_release_and_pour()

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

func _on_reroll_pressed():
	if Main.gold >= 2: # 리롤 비용 2달러 (가칭)
		Main.gold -= 2
		enter_shop_sequence()
	else:
		print("Not enough gold for reroll!")

func _refresh_random_items():
	available_shop_items.clear()
	var slots = random_items_container.get_children()
	
	for i in range(slots.size()):
		var slot = slots[i]
		var item_type = "joker" if randf() > 0.4 else "dice"
		var item_data = {}
		var price = 0
		
		if item_type == "joker":
			var random_joker = JokerManager.get_random_jokers(1)[0]
			item_data = random_joker
			price = random_joker["Price"]
			slot.get_node("VBox/Name").text = random_joker["korean_name"]
		else:
			# 특수 주사위 (아직 소유하지 않은 것 중 랜덤)
			var unowned = []
			for type_idx in range(1, 9):
				if not Main.owned_dice_types.has(type_idx):
					unowned.append(type_idx)
			
			if unowned.is_empty(): # 다 가졌으면 조커로 대체
				var random_joker = JokerManager.get_random_jokers(1)[0]
				item_data = random_joker
				item_type = "joker"
				price = random_joker["Price"]
				slot.get_node("VBox/Name").text = random_joker["korean_name"]
			else:
				var dice_idx = unowned[randi() % unowned.size()]
				item_data = Main.ALL_DICE_INFO[dice_idx]
				item_data["type_index"] = dice_idx
				price = 6 # 특수주사위 가격 6달러 고정
				slot.get_node("VBox/Name").text = item_data["name"]
		
		var buy_btn = slot.get_node("VBox/BuyButton")
		buy_btn.text = "Buy $%d" % price
		buy_btn.disabled = Main.gold < price
		
		# 버튼 연결 (기존 연결 해제 후 새로 연결)
		for conn in buy_btn.pressed.get_connections():
			buy_btn.pressed.disconnect(conn.callable)
		buy_btn.pressed.connect(_on_random_item_buy_pressed.bind(i))
		
		available_shop_items.append({"type": item_type, "data": item_data, "price": price})

func _on_random_item_buy_pressed(index: int):
	var item = available_shop_items[index]
	if Main.gold >= item.price:
		Main.gold -= item.price
		if item.type == "joker":
			Main.owned_jokers.append(item.data)
			emit_signal("joker_purchased")
		else:
			Main.owned_dice_types.append(item.data.type_index)
		
		# UI 업데이트
		_update_gold_label()
		if side_panel:
			side_panel.update_joker_inventory(Main.owned_jokers)
		
		# 구매 완료 표시
		var slot = random_items_container.get_child(index)
		slot.get_node("VBox/BuyButton").disabled = true
		slot.get_node("VBox/BuyButton").text = "SOLDOUT"

func _on_buy_joker_mode_selected():
	clear_shop_objects()
	current_mode = ShopMode.JOKER
	finished_dice_count = 0
	_is_aligning = false
	_setup_shop_scene()

func _setup_shop_scene():
	cup = CupScene.instantiate()
	# 상점 트레이 중앙
	cup.position = Vector3(0, 10, 0) 
	shop_area.add_child(cup)
	
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

func spawn_shop_dice(count: int):
	var world_node = shop_area.get_parent()
	if cup.has_method("_set_ceiling_collision"):
		cup._set_ceiling_collision(true)

	for i in range(count):
		var dice = shop_dice_scene.instantiate() as ShopDice
		world_node.add_child(dice)
		current_shop_dice.append(dice)
		dice.roll_finished.connect(_on_shop_dice_roll_finished)
		
		var offset = Vector3(randf_range(-0.5, 0.5), randf_range(0.5, 1.5), randf_range(-0.5, 0.5))
		dice.global_position = cup.global_position + offset
		
		var random_jokers = JokerManager.get_random_jokers(6)
		dice.setup_jokers(random_jokers)
		dice.setup_physics_for_spawning()

func _start_shaking():
	if is_instance_valid(cup) and cup.has_method("start_shaking"):
		cup.start_shaking()
	is_shaking = true

func _release_and_pour() -> void:
	if not is_instance_valid(cup): return
	is_shaking = false
	if cup.has_method("stop_shaking"): await cup.stop_shaking()
	
	for dice in current_shop_dice:
		dice.apply_outside_cup_physics()
		var impulse = Vector3(randf_range(-5, 5), randf_range(10, 15), randf_range(-5, 5))
		var torque = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		dice.apply_impulse_force(impulse, torque)
		dice.start_rolling()

	if cup.has_method("pour"): await cup.pour()
	if cup.has_method("_set_ceiling_collision"): cup._set_ceiling_collision(false)

func _on_shop_dice_roll_finished(_value: int, _dice_name: String):
	finished_dice_count += 1
	if finished_dice_count >= current_shop_dice.size():
		if not _is_aligning:
			_is_aligning = true
			await get_tree().create_timer(0.4).timeout
			_align_and_present_results()

func _align_and_present_results() -> void:
	var final_joker_data = []
	var target_rotations = []
	
	for dice in current_shop_dice:
		var face_idx = dice.get_top_face_index()
		final_joker_data.append(dice.assigned_jokers[face_idx])
		var face_val = ShopDice.JOKER_FACE_TO_DICE_FACE_MAP[face_idx]
		var target_rot = dice._get_rotation_for_face(face_val)
		target_rot.y = 0 
		target_rotations.append(target_rot)
	
	var center_x = shop_area.global_position.x
	var start_x = center_x - (current_shop_dice.size() - 1) * (GameConstants.DICE_SPACING / 2.0)
	var move_duration = GameConstants.MOVE_DURATION
	
	var master_tween = create_tween().set_parallel()
	for i in range(current_shop_dice.size()):
		var dice = current_shop_dice[i]
		dice.freeze = true
		dice.set_collision_enabled(false)
		
		var target_pos = Vector3(start_x + i * GameConstants.DICE_SPACING, shop_area.global_position.y + 2.0, shop_area.global_position.z)
		var target_quat = Quaternion.from_euler(Vector3(deg_to_rad(target_rotations[i].x), 0, deg_to_rad(target_rotations[i].z)))
		
		master_tween.tween_property(dice, "global_position", target_pos, move_duration)
		master_tween.tween_property(dice, "quaternion", target_quat, move_duration)

	await master_tween.finished
	_show_joker_purchase_popup(final_joker_data)

func _show_joker_purchase_popup(jokers: Array):
	# 기존 BuyPanel 대신 간단한 팝업이나 선택 로직을 구현해야 하지만,
	# 여기서는 간단히 클릭으로 선택할 수 있도록 주사위에 상호작용을 추가하거나
	# 기존 ShopHUD의 BuyPanel 로직을 활용할 수 있습니다.
	# 사용자님의 요청에 따라 "조커를 골라서 구매"하는 기능을 위해 
	# 각 주사위 위치 위에 구매 버튼을 띄우는 방식으로 처리하겠습니다.
	
	for i in range(jokers.size()):
		var joker = jokers[i]
		var dice = current_shop_dice[i]
		# 주사위 클릭 시 구매 로직 (간단화를 위해 로그로 대체하거나 작은 버튼 생성)
		# 여기서는 일단 로그로 표시하고, 실제 구매는 첫 번째 주사위로 테스트 가능하게 함
		print("Available Joker: ", joker["korean_name"], " Price: ", joker["Price"])

func _on_next_round_button_pressed() -> void:
	clear_shop_objects()
	StageManager.advance_to_next_round()
	emit_signal("go_to_game_requested")

func _update_gold_label() -> void:
	if side_panel: side_panel.update_gold(Main.gold)

func _on_view_dice_bag_pressed() -> void:
	pass
