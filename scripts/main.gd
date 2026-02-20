extends Node

# 전역 게임 상태를 관리합니다.

var stage: int = 1
var target_score: int = 300
var current_score: int = 0
var turns_left: int = 4
var invests_left: int = 5
var gold: int = 0 # 플레이어 재화
var owned_jokers: Array = [] # 플레이어가 소유한 조커 목록

# [추가] 주사위 종류 관련 변수
# [수정] 테스트를 위해 0~8번 주사위 모두 소유 상태로 시작
var owned_dice_types: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8] 

const ALL_DICE_INFO = {
	0: {"name": "Basic Dice", "description": "The standard dice.", "price": 0},
	1: {"name": "Plus Dice", "description": "Dice with a plus sign.", "price": 1},
	2: {"name": "Dollar Dice", "description": "Dice with a dollar sign.", "price": 1},
	3: {"name": "Multiply Dice", "description": "Dice with a multiply sign.", "price": 1},
	4: {"name": "Faceless Dice", "description": "Dice with no faces.", "price": 1},
	5: {"name": "Lucky 777 Dice", "description": "Special lucky dice.", "price": 1},
	6: {"name": "Growing Dice", "description": "Dice that grows.", "price": 1},
	7: {"name": "Ugly Dice", "description": "An ugly looking dice.", "price": 1},
	8: {"name": "Prism Dice", "description": "A beautiful prism dice.", "price": 1}
}

# [수정] 주사위 타입별 개별 조명 설정값
var dice_light_configs: Dictionary = {}
const CONFIG_PATH = "user://dice_lights.cfg"

func _init():
	load_light_configs()

# 설정값 저장 함수
func save_light_configs():
	var config = ConfigFile.new()
	for type_idx in dice_light_configs:
		var data = dice_light_configs[type_idx]
		for key in data:
			config.set_value("Dice_" + str(type_idx), key, data[key])
	config.save(CONFIG_PATH)
	print("Lights Config Saved to: ", OS.get_user_data_dir())

# 설정값 로드 함수
func load_light_configs():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	
	for i in range(9):
		var default_data = {
			"energy": 1.5,
			"range": 5.0,
			"attenuation": 2.5,
			"shake_speed": 1.5,
			"shake_amount": 0.1,
			"color": Color(1, 1, 1)
		}
		
		if err == OK:
			# 파일이 있으면 파일에서 읽어옴
			for key in default_data:
				default_data[key] = config.get_value("Dice_" + str(i), key, default_data[key])
		
		dice_light_configs[i] = default_data

func _ready() -> void:
	# Temporary: Add a sample joker for testing
	if owned_jokers.is_empty():
		var sample_joker = {
			"id": 1,
			"korean_name": "위스키잔",
			"english_name": "whiskey",
			"image_path": "res://assets/joker_images/whiskey.png",
			"description": "족보 성공 시 점수 +100",
			"unlock_condition": "기본",
			"Tier": "Common",
			"Price": 4
		}
		owned_jokers.append(sample_joker)
		print("Temporary: Added sample joker to Main.owned_jokers")
