extends Control
class_name DiceIcon

var body: Panel
var label: Label

func _ready():
	if get_child_count() == 0:
		_setup_ui()

func _setup_ui():
	custom_minimum_size = Vector2(60, 60)
	
	# 그림자 효과를 위한 배경 패널
	var shadow = Panel.new()
	shadow.custom_minimum_size = Vector2(60, 60)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.3)
	shadow_style.corner_radius_top_left = 12
	shadow_style.corner_radius_top_right = 12
	shadow_style.corner_radius_bottom_left = 12
	shadow_style.corner_radius_bottom_right = 12
	shadow.add_theme_stylebox_override("panel", shadow_style)
	shadow.position = Vector2(2, 2)
	add_child(shadow)
	
	var panel = Panel.new()
	panel.name = "Body"
	panel.custom_minimum_size = Vector2(60, 60)
	add_child(panel)
	body = panel
	
	var style_box = StyleBoxFlat.new()
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	style_box.set_border_width_all(3)
	style_box.border_color = Color.WHITE
	panel.add_theme_stylebox_override("panel", style_box)
	
	var l = Label.new()
	l.name = "Label"
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	label = l

func set_dice(color: Color, type_index: int):
	if not body: _setup_ui()
	
	var style_box = body.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style_box.bg_color = color
	
	# 검은색 주사위는 테두리를 더 밝게, 흰색은 더 어둡게
	if color.is_equal_approx(Color.BLACK):
		style_box.border_color = Color(0.6, 0.6, 0.6)
	elif color.is_equal_approx(Color.WHITE):
		style_box.border_color = Color(0.8, 0.8, 0.8)
	else:
		style_box.border_color = Color(1, 1, 1, 0.7)
		
	body.add_theme_stylebox_override("panel", style_box)
	
	# 색상에 따른 글자색 자동 조절
	if color.v > 0.7: # 밝은 색상
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_color_override("font_outline_color", Color.WHITE)
	else: # 어두운 색상
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	match type_index:
		0: label.text = "::"
		1: label.text = "+"
		2: label.text = "$"
		3: label.text = "x"
		4: label.text = "?"
		5: label.text = "7"
		6: label.text = "^"
		7: label.text = "!"
		8: label.text = "*"
		9: label.text = "S"
		_: label.text = ""
