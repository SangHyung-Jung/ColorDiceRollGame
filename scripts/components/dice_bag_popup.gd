extends Window

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

	# GameConstants를 기반으로 2D UI를 동적으로 생성합니다.
	for key in GameConstants.BAG_COLOR_MAP:
		var color = GameConstants.BAG_COLOR_MAP[key]
		
		# --- 2D 색상 사각형 생성 ---
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(60, 60)
		color_rect.color = color
		# 검은색 사각형이 잘 보이도록 테두리를 추가합니다.
		if color == Color.BLACK:
			var style_box = StyleBoxFlat.new()
			style_box.set_border_width_all(2)
			style_box.border_color = Color.WHITE
			style_box.bg_color = Color.BLACK
			var panel = Panel.new()
			panel.custom_minimum_size = Vector2(60, 60)
			panel.add_theme_stylebox_override("panel", style_box)
			grid.add_child(panel)
		else:
			grid.add_child(color_rect)
		
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
