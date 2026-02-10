extends Node

# 전역 게임 상태를 관리합니다.

var stage: int = 1
var target_score: int = 300
var current_score: int = 0
var turns_left: int = 4
var invests_left: int = 5
var gold: int = 0 # 플레이어 재화
var owned_jokers: Array = [] # 플레이어가 소유한 조커 목록

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

