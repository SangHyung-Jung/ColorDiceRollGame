extends Window

# 3D 주사위 표시를 위해 InvestedDie3DScene을 로드합니다.
const InvestedDie3DScene = preload("res://scripts/components/invested_die_3d.tscn")

const COLORS = [
	{"key": "W", "name": "하얀색", "color_enum": ColoredDice.DiceColor.WHITE},
	{"key": "K", "name": "검은색", "color_enum": ColoredDice.DiceColor.BLACK},
	{"key": "R", "name": "빨간색", "color_enum": ColoredDice.DiceColor.RED},
	{"key": "G", "name": "초록색", "color_enum": ColoredDice.DiceColor.GREEN},
	{"key": "B", "name": "파란색", "color_enum": ColoredDice.DiceColor.BLUE},
]

# 이제 각 색상 키에 대해 레이블 노드만 저장합니다.
var ui_labels: Dictionary = {} # { "W": label_node, "K": label_node, ... }

func _ready():
	close_requested.connect(hide)
	
	var grid = get_node("MarginContainer/GridContainer")
	if not grid:
		push_error("GridContainer not found in DiceBagPopup!")
		return
		
	# 기존 자식 노드를 모두 제거하여 중복 생성을 방지합니다.
	for child in grid.get_children():
		child.queue_free()

	# 3D 주사위와 레이블을 생성하여 그리드에 추가합니다.
	for color_info in COLORS:
		var key = color_info["key"]
		
		# --- 3D 주사위 표시 UI 생성 ---
		var display_3d = InvestedDie3DScene.instantiate()
		display_3d.custom_minimum_size = Vector2(60, 60)
		
		# --- 실제 3D 주사위 노드 생성 ---
		var dice_node = ColoredDice.new()
		# setup_dice를 호출하기 전에 임시로 씬에 추가해야 내부 노드들이 생성됨
		add_child(dice_node)
		dice_node.setup_dice(color_info["color_enum"])
		# 실제 씬에는 추가하지 않을 것이므로 다시 제거
		remove_child(dice_node)
		
		# 3D 주사위를 3D 디스플레이에 설정 (값은 6으로 고정하여 표시)
		display_3d.value = 6
		display_3d.set_die(dice_node)
		
		grid.add_child(display_3d)
		
		# --- 개수 표시 레이블 생성 ---
		var label = Label.new()
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("font_size", 24)
		grid.add_child(label)
		
		# 나중에 개수를 업데이트하기 위해 레이블을 저장합니다.
		ui_labels[key] = label

func update_counts(dice_bag: DiceBag):
	if not dice_bag:
		print("DiceBag is null, cannot update counts.")
		return
		
	for color_key in ui_labels:
		var label_node = ui_labels[color_key]
		var count = dice_bag.count_of(color_key)
		label_node.text = " :  " + str(count)
