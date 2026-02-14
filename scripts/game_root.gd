extends Node3D
class_name GameRoot

@onready var camera = $MainCamera
@onready var game_hud = $UI_Canvas/GameHUD
@onready var shop_hud = $UI_Canvas/ShopHUD
@onready var start_screen = $UI_Canvas/StartScreen
@onready var joker_dictionary = $UI_Canvas/JokerDictionary
@onready var light_config_screen = $UI_Canvas/LightConfigScreen # [추가]
@onready var world_3d = $"3D_World"
@onready var floating_text_container = $EffectsLayer/FloatingTextContainer
@onready var input_manager: InputManager = $InputManager

const POS_GAME = Vector3(-6, 15, 0) # 게임 플레이 카메라 위치
const POS_SHOP = Vector3(55.6, 20, 0) # 상점 카메라 위치
# [추가] 시작 화면 카메라 위치 (게임 화면 왼쪽 멀리)
const POS_START = Vector3(-40, 20, 0) 

const ROT_GAME = Vector3(-90, 0, 0)
const ROT_SHOP = Vector3(-90, 0, 0) # 상점도 게임과 같은 탑다운 뷰 사용
# [추가] 시작 화면도 탑다운 뷰 유지 (필요하면 각도 변경 가능)
const ROT_START = Vector3(-90, 0, 0)
const POS_DICTIONARY = Vector3(-80, 20, 0)
const ROT_DICTIONARY = Vector3(-90, 0, 0)
# [추가] 조명 설정 화면 카메라 위치
const POS_LIGHT_CONFIG = Vector3(-120, 20, 0)
const ROT_LIGHT_CONFIG = Vector3(-90, 0, 0)

var is_in_game_view: bool = false

func _ready():
	# Initial setup of game hud. This creates all the necessary manager nodes.
	# 사운드 미리 로드
	SoundManager.preload_sound("die_on_cup", "res://assets/audio/dice-throw-3.ogg")
	SoundManager.preload_sound("die_on_die", "res://assets/audio/dice-throw-1.ogg")

	game_hud.setup_game_hud(world_3d, camera, floating_text_container)
	
	# Initialize InputManager now that game_hud (and its combo_select) is ready.
	input_manager.initialize(game_hud.combo_select, camera)
	input_manager.roll_started.connect(game_hud.start_roll_animation)
	input_manager.roll_released.connect(game_hud.handle_roll_release)

	# [변경] 게임 시작 시 바로 게임이 아닌 '시작 화면'으로 초기화
	# transition_to_game(true) -> 삭제
	
	# UI에서 발생하는 시그널 연결
	game_hud.connect("go_to_shop_requested", Callable(self, "transition_to_shop"))
	shop_hud.connect("go_to_game_requested", Callable(self, "transition_to_game"))
	shop_hud.joker_purchased.connect(_on_joker_purchased)

	# [추가] 시작 화면 시그널 연결
	if start_screen:
		start_screen.start_game_requested.connect(transition_to_game)
		start_screen.joker_dictionary_requested.connect(transition_to_dictionary)
		start_screen.shop_requested.connect(transition_to_shop)
		start_screen.light_config_requested.connect(transition_to_light_config) # [추가]
	
	# [추가] 조커 사전 시그널 연결
	if joker_dictionary:
		joker_dictionary.back_requested.connect(transition_to_start)
	
	# [추가] 조명 설정 시그널 연결
	if light_config_screen:
		light_config_screen.back_requested.connect(transition_to_start)

	# 시작 화면 진입 (즉시 이동)
	transition_to_start(true)


func _on_joker_purchased():
	if game_hud:
		game_hud.update_joker_dice_display()


func _unhandled_input(event: InputEvent) -> void:
	if is_in_game_view:
		input_manager.handle_input(event)

func _process(_delta):
	# GameHUD UI 위치 보정 (기존 로직 유지)
	if game_hud.visible:
		var viewport_rect = get_viewport().get_visible_rect()
		var screen_center = viewport_rect.size / 2
		var game_world_pos_on_screen = camera.unproject_position(POS_GAME)
		game_hud.position = game_world_pos_on_screen - screen_center

# [추가] 조명 설정 화면으로 전환하는 함수
func transition_to_light_config():
	is_in_game_view = false
	input_manager.set_roll_in_progress(true)

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", POS_LIGHT_CONFIG, 1.5)
	tween.tween_property(camera, "rotation_degrees", ROT_LIGHT_CONFIG, 1.5)

	tween.chain().tween_callback(func():
		game_hud.visible = false
		shop_hud.visible = false
		if start_screen: start_screen.visible = false
		if joker_dictionary: joker_dictionary.visible = false
		if light_config_screen: light_config_screen.visible = true
		input_manager.set_roll_in_progress(false)
	)

# [추가] 시작 화면으로 전환하는 함수
func transition_to_start(instant: bool = false):
	is_in_game_view = false
	input_manager.set_roll_in_progress(true) # 시작 화면에서는 주사위 조작 금지

	if instant:
		camera.global_position = POS_START
		camera.rotation_degrees = ROT_START
		# UI 상태 설정
		game_hud.visible = false
		shop_hud.visible = false
		if start_screen:
			start_screen.visible = true
		if joker_dictionary:
			joker_dictionary.visible = false
		if light_config_screen: light_config_screen.visible = false
		input_manager.set_roll_in_progress(false)
		return

	# Camera Tween
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", POS_START, 1.5)
	tween.tween_property(camera, "rotation_degrees", ROT_START, 1.5)

	tween.chain().tween_callback(func():
		# UI 상태 설정
		game_hud.visible = false
		shop_hud.visible = false
		if start_screen:
			start_screen.visible = true
		if joker_dictionary:
			joker_dictionary.visible = false
		if light_config_screen: light_config_screen.visible = false
		input_manager.set_roll_in_progress(false) # Re-enable input if needed for start screen
	)

func transition_to_dictionary():
	is_in_game_view = false
	input_manager.set_roll_in_progress(true) # Disable dice input for dictionary screen

	# Camera Tween
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", POS_DICTIONARY, 1.5)
	tween.tween_property(camera, "rotation_degrees", ROT_DICTIONARY, 1.5)

	tween.chain().tween_callback(func():
		game_hud.visible = false
		shop_hud.visible = false
		if start_screen: start_screen.visible = false
		if joker_dictionary:
			joker_dictionary.visible = true
		if light_config_screen: light_config_screen.visible = false
		input_manager.set_roll_in_progress(false) # Re-enable input if needed for dictionary (e.g., scrolling)
	)

func transition_to_shop():
	is_in_game_view = false
	input_manager.set_roll_in_progress(true) # Disable game input during transition

	# Camera Tween
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", POS_SHOP, 1.5)
	tween.tween_property(camera, "rotation_degrees", ROT_SHOP, 1.5)
	
	tween.chain().tween_callback(func():
		game_hud.visible = false
		if start_screen: start_screen.visible = false # 혹시 켜져있으면 끄기
		if joker_dictionary: joker_dictionary.visible = false
		if light_config_screen: light_config_screen.visible = false
		shop_hud.visible = true
		shop_hud.enter_shop_sequence() # 상점 진입 애니메이션/로직 실행
		input_manager.set_roll_in_progress(false) # Re-enable input for shop (if any)
	)

func transition_to_game(instant: bool = false):
	is_in_game_view = true
	# UI 정리
	shop_hud.visible = false
	if start_screen:
		start_screen.visible = false # 시작 화면 숨김
	if joker_dictionary:
		joker_dictionary.visible = false
	if light_config_screen: light_config_screen.visible = false
	input_manager.set_roll_in_progress(true) # Disable shop input during transition
	
	if instant:
		camera.global_position = POS_GAME
		camera.rotation_degrees = ROT_GAME
		game_hud.visible = true

		# [추가] 즉시 이동 시에도 위치 갱신 필요
		game_hud.update_socket_positions() 
		# [추가] 조커 소켓 및 주사위 업데이트
		await game_hud.update_joker_socket_positions()
		game_hud.update_joker_dice_display()
		game_hud.start_round_sequence() # 게임 라운드 시작 로직
		input_manager.set_roll_in_progress(false) # Re-enable input for game
		return

	# Prepare GameHUD for transition
	game_hud.visible = true

	# Camera Tween
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", POS_GAME, 1.5)
	tween.tween_property(camera, "rotation_degrees", ROT_GAME, 1.5)
	
	tween.chain().tween_callback(func():
		# [핵심] 카메라가 도착했으므로, 이제 현재 카메라 기준으로 소켓 위치를 다시 계산하라고 명령
		game_hud.update_socket_positions()
		# [추가] 조커 소켓 및 주사위 업데이트
		await game_hud.update_joker_socket_positions()
		game_hud.update_joker_dice_display()

		# game_hud is already visible
		game_hud.start_round_sequence() # 게임 라운드 시작 로직
		input_manager.set_roll_in_progress(false) # Re-enable input for game
	)
