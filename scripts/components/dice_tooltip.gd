extends PanelContainer

@onready var name_label = $VBox/DiceName
@onready var desc_label = $VBox/Description

func _ready():
	hide() # 처음에 숨김

func show_dice_info(type_index: int):
	var info = Main.ALL_DICE_INFO.get(type_index, {"name": "Unknown", "description": "No data"})
	name_label.text = info["name"]
	desc_label.text = info["description"]
	show()

func update_position(mouse_pos: Vector2):
	# 마우스 커서 살짝 오른쪽 아래에 위치
	global_position = mouse_pos + Vector2(25, 25)
	
	# 화면 밖으로 나가지 않게 보정
	var screen_size = get_viewport_rect().size
	if global_position.x + size.x > screen_size.x:
		global_position.x = mouse_pos.x - size.x - 25
	if global_position.y + size.y > screen_size.y:
		global_position.y = mouse_pos.y - size.y - 25
