extends Control
class_name ShopScreen

# UI 노드 참조
@onready var joker_grid_container: GridContainer = $MainLayout/GameArea/ScrollContainer/JokerGridContainer
@onready var next_round_button: Button = $MainLayout/GameArea/ShopHeader/NextRoundButton

# 리소스 로드
const JokerShopItemScene = preload("res://scenes/components/joker_shop_item.tscn")


func _ready() -> void:
	# 다음 라운드 시작 버튼 시그널 연결
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	
	# 상점 아이템 채우기
	_populate_shop_items()

## JokerManager에서 조커 목록을 가져와 상점 아이템을 생성하고 그리드에 추가합니다.
func _populate_shop_items() -> void:
	# 기존 아이템이 있다면 모두 삭제 (리롤 등을 위해)
	for child in joker_grid_container.get_children():
		child.queue_free()
		
	# JokerManager에서 모든 조커 데이터를 가져옵니다.
	var all_jokers = JokerManager.get_all_jokers()
	
	if all_jokers.is_empty():
		print("JokerManager has no joker data.")
		return

	# 각 조커에 대해 아이템 씬을 인스턴스화하고 설정합니다.
	for joker_info in all_jokers:
		var joker_item = JokerShopItemScene.instantiate()
		joker_item.joker_info = joker_info # 데이터를 먼저 할당합니다.
		joker_grid_container.add_child(joker_item) # 그 다음에 씬 트리에 추가합니다.

## '다음 라운드' 버튼을 누르면 다음 라운드 상태로 설정하고 메인 게임 화면으로 돌아갑니다.
func _on_next_round_button_pressed() -> void:
	StageManager.advance_to_next_round()
	get_tree().change_scene_to_file("res://main_screen.tscn")
