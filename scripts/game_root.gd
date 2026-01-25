extends Node3D
class_name GameRoot

@onready var camera = $MainCamera
@onready var game_hud = $UI_Canvas/GameHUD
@onready var shop_hud = $UI_Canvas/ShopHUD
@onready var world_3d = $"3D_World"
@onready var floating_text_container = $EffectsLayer/FloatingTextContainer
@onready var input_manager: InputManager = $InputManager

const POS_GAME = Vector3(-6, 15, 0) # 게임 플레이 카메라 위치
const POS_SHOP = Vector3(30, 20, 0) # 상점 카메라 위치

const ROT_GAME = Vector3(-90, 0, 0)
const ROT_SHOP = Vector3(-90, 0, 0) # 상점도 게임과 같은 탑다운 뷰 사용

func _ready():
	# Initial setup of game hud. This creates all the necessary manager nodes.
	game_hud.setup_game_hud(world_3d, camera, floating_text_container)
	
	# Initialize InputManager now that game_hud (and its combo_select) is ready.
	input_manager.initialize(game_hud.combo_select, camera)
	input_manager.roll_started.connect(game_hud.start_roll_animation)
	input_manager.roll_released.connect(game_hud.handle_roll_release)

	# 게임 시작 시 게임 화면으로 초기화
	transition_to_game(true)
	
	# UI에서 발생하는 시그널 연결
	game_hud.connect("go_to_shop_requested", Callable(self, "transition_to_shop"))
	shop_hud.connect("go_to_game_requested", Callable(self, "transition_to_game"))


func _unhandled_input(event: InputEvent) -> void:
	input_manager.handle_input(event)


func transition_to_shop():
	input_manager.set_roll_in_progress(true) # Disable game input during transition
	
	# Animate SocketArea out
	var socket_area = game_hud.get_node("MainLayout/SocketArea")
	var ui_tween = create_tween()
	ui_tween.tween_property(socket_area, "position:x", -1500, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# Camera Tween
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", POS_SHOP, 1.5)
	tween.tween_property(camera, "rotation_degrees", ROT_SHOP, 1.5)
	
	tween.chain().tween_callback(func():
		game_hud.visible = false # Hide the whole thing after transition
		socket_area.position.x = 0 # Reset for next time
		shop_hud.visible = true
		shop_hud.enter_shop_sequence() # 상점 진입 애니메이션/로직 실행
		input_manager.set_roll_in_progress(false) # Re-enable input for shop (if any)
	)

func transition_to_game(instant: bool = false):
	shop_hud.visible = false
	input_manager.set_roll_in_progress(true) # Disable shop input during transition
	
	if instant:
		camera.global_position = POS_GAME
		camera.rotation_degrees = ROT_GAME
		game_hud.visible = true
		game_hud.start_round_sequence() # 게임 라운드 시작 로직
		input_manager.set_roll_in_progress(false) # Re-enable input for game
		return

	# Prepare GameHUD for transition
	var socket_area = game_hud.get_node("MainLayout/SocketArea")
	socket_area.position.x = -1500 # Start it off-screen
	game_hud.visible = true

	# Animate SocketArea in
	var ui_tween = create_tween()
	ui_tween.tween_property(socket_area, "position:x", 0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# Camera Tween
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", POS_GAME, 1.5)
	tween.tween_property(camera, "rotation_degrees", ROT_GAME, 1.5)
	
	tween.chain().tween_callback(func():
		# game_hud is already visible
		game_hud.start_round_sequence() # 게임 라운드 시작 로직
		input_manager.set_roll_in_progress(false) # Re-enable input for game
	)
