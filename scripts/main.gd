extends Node

var stage: int = 1
var target_score: int = 300
var current_score: int = 0
var turns_left: int = 4
var invests_left: int = 5
var gold: int = 0 
var owned_jokers: Array = [] 
#var owned_dice_types: Array = [0] 
var owned_dice_types: Array = [0,1,2,3,4,5,6,7,8] 
const ALL_DICE_INFO = {
	0: {"name": "Basic Dice", "description": "Standard dice without special effects.", "price": 0},
	1: {"name": "Plus Dice", "description": "Adds +50 to the base score of the combination.", "price": 1},
	2: {"name": "Dollar Dice", "description": "Gives +$2 bonus when used in a combination.", "price": 1},
	3: {"name": "Multiply Dice", "description": "Doubles the final multiplier of the combination.", "price": 1},
	4: {"name": "Faceless Dice", "description": "Acts as a wildcard for any number.", "price": 1},
	5: {"name": "Lucky Dice", "description": "Special lucky dice (Effect TBD).", "price": 1},
	6: {"name": "Growing Dice", "description": "Dice that grows stronger (Effect TBD).", "price": 1},
	7: {"name": "Ugly Dice", "description": "An ugly looking dice (Effect TBD).", "price": 1},
	8: {"name": "Prism Dice", "description": "Acts as a wildcard for any color.", "price": 1}
}

var dice_light_configs: Dictionary = {}

func _init():
	for i in range(9):
		dice_light_configs[i] = {
			"energy": 1.0,       # 옴니 조명은 스포트라이트보다 적은 에너지로 충분합니다.
			"range": 2.0,
			"attenuation": 1.5,
			"height": 1.5,       # 중앙 쏠림 방지를 위해 여전히 낮게 유지
			"specular": 0.0,
			"shake_speed": 0.0,
			"shake_amount": 0.0,
			"color": Color(1, 1, 1)
		}
	dice_light_configs[6]["attenuation"] = 2.5
	dice_light_configs[6]["height"] = 3.0
	dice_light_configs[6]["range"] = 3.0
	dice_light_configs[5]["attenuation"] = 5.0
	dice_light_configs[5]["specular"] = 16.0

func _ready() -> void:
	if owned_jokers.is_empty():
		owned_jokers.append({"id": 1, "korean_name": "위스키잔", "english_name": "whiskey", "Price": 4})
