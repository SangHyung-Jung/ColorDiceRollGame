extends Control
class_name ShopHUD
signal go_to_game_requested

# UI 노드 참조

@onready var next_round_button: Button = $MainLayout/GameArea/ShopHeader/NextRoundButton
@onready var gold_label: Label = $MainLayout/InfoPanel/Panel/VBoxContainer/GoldLabel
@onready var joker_inventory: HBoxContainer = $MainLayout/InfoPanel/Panel/VBoxContainer/JokerInventory

# 리소스 로드

func _ready() -> void:
	# 다음 라운드 시작 버튼 시그널 연결
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	# enter_shop_sequence() # Called by GameRoot when transitioning to shop



func enter_shop_sequence() -> void:
	# This function will be called by GameRoot when transitioning to shop
	_update_gold_label()
	joker_inventory.update_display(Main.owned_jokers)

## '다음 라운드' 버튼을 누르면 다음 라운드 상태로 설정하고 메인 게임 화면으로 돌아갑니다.
func _on_next_round_button_pressed() -> void:
	StageManager.advance_to_next_round()
	emit_signal("go_to_game_requested")

## 골드 UI를 업데이트합니다.
func _update_gold_label() -> void:
	gold_label.text = "Gold: $%d" % Main.gold

## 아이템 구매 시 호출될 함수
func _on_item_purchased() -> void:
	_update_gold_label()
	joker_inventory.update_display(Main.owned_jokers)
