extends Window

func _ready():
	close_requested.connect(hide)
	# Window 크기를 좀 더 넉넉하게 조정
	size = Vector2i(550, 700)
	
	_setup_base_ui()

var main_container: VBoxContainer

func _setup_base_ui():
	# 기존 MarginContainer 내의 GridContainer를 제거하고 ScrollContainer 추가
	var margin = get_node("MarginContainer")
	for child in margin.get_children():
		child.queue_free()
	
	# 검은색 주사위가 잘 보이도록 어두운 회색 배경의 Panel 추가
	var bg_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15) # 너무 검지 않은 회색
	bg_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(bg_panel)
		
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg_panel.add_child(scroll)
	
	main_container = VBoxContainer.new()
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 내부 마진 추가
	main_container.add_theme_constant_override("separation", 10)
	scroll.add_child(main_container)

func _add_section_header(container: Container, title: String):
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.GOLD)
	# 상단 여백을 위한 더미 레이블 대신 마진 설정
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	container.add_child(spacer)
	
	container.add_child(label)
	
	var hs = HSeparator.new()
	container.add_child(hs)

func update_counts(dice_bag: DiceBag):
	if not dice_bag: return
	if not main_container: _setup_base_ui()
	
	# 중복 생성 방지를 위해 먼저 모두 비우기
	for child in main_container.get_children():
		child.queue_free()

	_add_section_header(main_container, "Remaining Dice in Bag")
	
	# 1. 색상별 주사위 그룹핑 (일반 + 해당 색상의 특수)
	for color_key in GameConstants.BAG_COLOR_MAP:
		var color_dice = dice_bag.get_dice_by_color(color_key)
		if color_dice.is_empty(): continue
		
		# Prism(8) 등 색상 구분이 없는 주사위는 이 단계에서 제외
		var filtered_dice = []
		for d in color_dice:
			if d.type != 8: # 8번 Prism은 Neutral 섹션으로
				filtered_dice.append(d)
		
		if filtered_dice.is_empty(): continue

		var color_name = _get_color_display_name(color_key)
		var color_label = Label.new()
		color_label.text = "  " + color_name + " Dice (" + str(filtered_dice.size()) + ")"
		color_label.add_theme_font_size_override("font_size", 18)
		main_container.add_child(color_label)
		
		var flow = HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		main_container.add_child(flow)
		
		for i in range(filtered_dice.size()):
			var d = filtered_dice[i]
			var icon = Dice3DIcon.new()
			flow.add_child(icon)
			
			# 눈금은 1~6 순환 (사용자 요청: 1부터 올라가게)
			var face_val = (i % 6) + 1
			_setup_icon_deferred(icon, d.color, d.type, face_val)

	# 2. 색상 구분이 없는 특수 주사위 (Neutral Special Dice)
	var neutral_dice = dice_bag.get_neutral_dice()
	if not neutral_dice.is_empty():
		_add_section_header(main_container, "Neutral Special Dice")
		
		var flow = HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 10)
		main_container.add_child(flow)
		
		for i in range(neutral_dice.size()):
			var d = neutral_dice[i]
			var icon = Dice3DIcon.new()
			flow.add_child(icon)
			_setup_icon_deferred(icon, d.color, d.type, 1)

func _get_color_display_name(key: String) -> String:
	match key:
		"W": return "White"
		"K": return "Black"
		"R": return "Red"
		"G": return "Green"
		"B": return "Blue"
	return "Unknown"

func _setup_icon_deferred(icon: Dice3DIcon, color_key: String, type_index: int, face_val: int):
	# 뷰포트가 완전히 로드될 시간을 주기 위해 한 프레임 대기 후 호출
	await get_tree().process_frame
	if is_instance_valid(icon):
		icon.setup_dice(color_key, type_index, face_val)
