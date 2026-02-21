extends Control

signal back_requested

@onready var sliders = {
	"energy": $Controls/Energy/Slider,
	"range": $Controls/Range/Slider,
	"attenuation": $Controls/Attenuation/Slider,
	"shake_speed": $Controls/ShakeSpeed/Slider,
	"shake_amount": $Controls/ShakeAmount/Slider,
	"height": $Controls/Height/Slider
}
@onready var dice_selection_container = $Selection/DiceButtons

const PinpointLightScene = preload("res://scenes/effects/pinpoint_light.tscn")
var selected_dice_type: int = 0

func _ready():
	# 슬라이더 연결
	for key in sliders:
		sliders[key].value_changed.connect(_on_slider_changed.bind(key))
	
	$BackButton.pressed.connect(func(): back_requested.emit())
	
	# 주사위 선택 버튼 생성 및 연결
	_setup_selection_buttons()
	_setup_dice_previews()
	
	# 초기 선택 (0번 주사위)
	select_dice_type(0)

func _setup_selection_buttons():
	# 기존 버튼 제거
	for child in dice_selection_container.get_children():
		child.queue_free()
		
	for i in range(9):
		var btn = Button.new()
		var info = Main.ALL_DICE_INFO[i]
		btn.text = info["name"]
		btn.custom_minimum_size = Vector2(120, 50)
		btn.pressed.connect(select_dice_type.bind(i))
		dice_selection_container.add_child(btn)

func select_dice_type(type_index: int):
	selected_dice_type = type_index
	$Controls/SelectedDiceTitle.text = "Editing: " + Main.ALL_DICE_INFO[type_index]["name"]
	
	# 선택된 주사위의 설정값으로 슬라이더 업데이트
	var config = Main.dice_light_configs[type_index]
	for key in sliders:
		# 신호 발생 없이 값만 변경하기 위해 set_value_no_signal 사용 (순환 참조 방지)
		sliders[key].set_value_no_signal(config[key])
		_update_value_label(key, config[key])
	
	# 시각적 피드백: 선택된 주사위만 밝게 하거나 카메라 이동 가능 (일단 텍스트로 표시)
	print("Selected Dice Type for Editing: ", type_index)

func _setup_dice_previews():
	var config_area = get_tree().root.get_node_or_null("GameRoot/3D_World/LightConfigArea")
	if not config_area: return
		
	for child in config_area.get_children():
		child.queue_free()

	for i in range(9):
		var dice = ColoredDice.new()
		config_area.add_child(dice)
		# 3x3 격자 형태로 배치 (간격을 조금 좁힘)
		var row = i / 3
		var col = i % 3
		var spawn_pos = config_area.global_position + Vector3(col * 4 - 4, 0, row * 4 - 4)
		
		# [수정] 주사위 색상을 파란색으로 변경
		dice.setup_dice(ColoredDice.DiceColor.BLUE, spawn_pos, i)
		dice.freeze = true
		
		var light = PinpointLightScene.instantiate()
		config_area.add_child(light)
		light.target_node = dice

func _on_slider_changed(value: float, key: String):
	# 현재 선택된 주사위의 설정만 변경 (메모리)
	Main.dice_light_configs[selected_dice_type][key] = value
	_update_value_label(key, value)
	# (저장 함수 호출 삭제)

func _update_value_label(key: String, value: float):
	var label = get_node_or_null("Controls/" + key.capitalize() + "/ValueLabel")
	if label: label.text = str(snapped(value, 0.01))
