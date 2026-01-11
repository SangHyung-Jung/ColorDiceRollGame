extends PanelContainer
class_name RoundClearPopup

signal continue_pressed

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var details_label: Label = $MarginContainer/VBoxContainer/DetailsLabel
@onready var base_reward_label: Label = $MarginContainer/VBoxContainer/RewardGrid/BaseRewardLabel
@onready var turns_bonus_label: Label = $MarginContainer/VBoxContainer/RewardGrid/TurnsBonusLabel
@onready var interest_bonus_label: Label = $MarginContainer/VBoxContainer/RewardGrid/InterestBonusLabel
@onready var overachieve_bonus_label: Label = $MarginContainer/VBoxContainer/RewardGrid/OverachieveBonusLabel
@onready var total_reward_label: Label = $MarginContainer/VBoxContainer/TotalRewardLabel
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	# 초기에는 숨겨둡니다.
	hide()

## 팝업의 내용을 설정합니다.
func setup(round: int, target: int, result: int, rewards: Dictionary) -> void:
	title_label.text = "Round %d Clear!" % round
	details_label.text = "Target: %d / Result: %d" % [target, result]
	
	base_reward_label.text = "+ $%d" % rewards.get("base", 0)
	turns_bonus_label.text = "+ $%d" % rewards.get("turns", 0)
	interest_bonus_label.text = "+ $%d" % rewards.get("interest", 0)
	overachieve_bonus_label.text = "+ $%d" % rewards.get("over_achieve", 0)
	total_reward_label.text = "총 획득: + $%d" % rewards.get("total", 0)


## 팝업을 중앙에 표시합니다.
func popup_centered() -> void:
	show()
	var viewport_size = get_viewport_rect().size
	# 팝업 크기를 동적으로 조절 (옵션)
	# set_size(Vector2(400, 500)) 
	position = (viewport_size - size) / 2

func _on_continue_pressed() -> void:
	hide()
	continue_pressed.emit()
