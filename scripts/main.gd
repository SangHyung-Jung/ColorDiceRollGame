extends Node

# 전역 게임 상태를 관리합니다.

var stage: int = 1
var target_score: int = 300
var current_score: int = 0
var turns_left: int = 4
var invests_left: int = 5
var gold: int = 0 # 플레이어 재화
var owned_jokers: Array = [] # 플레이어가 소유한 조커 목록
