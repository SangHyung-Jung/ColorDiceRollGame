extends PanelContainer
class_name RoundClearPopup

signal continue_pressed

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var details_label: Label = $MarginContainer/VBoxContainer/DetailsLabel
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	# 초기에는 숨겨둡니다.
	hide()

## 팝업의 내용을 설정합니다.
## @param round: 클리어한 라운드 번호
## @param target: 목표 점수
## @param result: 달성한 점수
func setup(round: int, target: int, result: int) -> void:
	title_label.text = "Round %d Clear!" % round
	details_label.text = "Target: %d / Result: %d" % [target, result]

## 팝업을 중앙에 표시합니다.
func popup_centered() -> void:
	show()
	var viewport_size = get_viewport_rect().size
	position = (viewport_size - size) / 2

func _on_continue_pressed() -> void:
	hide()
	continue_pressed.emit()
