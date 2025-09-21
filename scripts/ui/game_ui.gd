class_name GameUI
extends CanvasLayer

@onready var stage_label = $MainContainer/RootHBox/CenterVBox/TopFieldHBox/StageLabel
@onready var opponent_label = $MainContainer/RootHBox/CenterVBox/TopFieldHBox/OpponentLabel
@onready var target_score_label = $MainContainer/RootHBox/CenterVBox/TopFieldHBox/TargetScoreLabel
@onready var boss_rule_label = $MainContainer/RootHBox/CenterVBox/BossRuleLabel
@onready var score_label = $MainContainer/RootHBox/LeftPanelContainer/LeftVBox/ScoreLabel
@onready var funds_label = $MainContainer/RootHBox/LeftPanelContainer/LeftVBox/FundsLabel
@onready var hand_count_label = $MainContainer/RootHBox/LeftPanelContainer/LeftVBox/HandCountLabel
@onready var invest_count_label = $MainContainer/RootHBox/LeftPanelContainer/LeftVBox/InvestCountLabel
@onready var hand_dice_container = $MainContainer/RootHBox/CenterVBox/DiceDisplays/HandDiceDisplay/HandDicePlaceholder
@onready var field_dice_container = $MainContainer/RootHBox/CenterVBox/DiceDisplays/FieldDiceDisplay/FieldDicePlaceholder
@onready var submit_combo_button = $MainContainer/RootHBox/RightPanelContainer/RightVBox/ActionButtons/SubmitComboButton
@onready var invest_button = $MainContainer/RootHBox/RightPanelContainer/RightVBox/ActionButtons/InvestButton
@onready var help_button = $MainContainer/RootHBox/RightPanelContainer/RightVBox/ActionButtons/HelpButton
@onready var dice_rolling_area = $MainContainer/RootHBox/CenterVBox/DiceRollingArea
@onready var help_panel = $HelpPanel
@onready var guide_text_label = $HelpPanel/VBox/GuideText
@onready var close_help_button = $HelpPanel/VBox/CloseHelpButton

signal submit_combo_pressed()
signal invest_pressed()

func _ready():
	submit_combo_button.pressed.connect(on_submit_combo_pressed)
	invest_button.connect("pressed", Callable(self, "on_invest_pressed"))
	help_button.pressed.connect(_on_help_button_pressed)
	close_help_button.pressed.connect(_on_close_help_button_pressed)
	update_boss_rule("None") # Initial state

func update_stage_info(stage_name: String, opponent_name: String, target_score: int):
	stage_label.text = "Stage: " + stage_name
	opponent_label.text = "Opponent: " + opponent_name
	target_score_label.text = "Target Score: " + str(target_score)

func update_score(new_score: int):
	score_label.text = "Score: " + str(new_score)

func update_funds(new_funds: int):
	funds_label.text = "Funds: $" + str(new_funds)

func update_hand_invest_counts(hand_count: int, invest_count: int):
	hand_count_label.text = "Submissions Left: " + str(hand_count)
	invest_count_label.text = "Investments Left: " + str(invest_count)

func update_boss_rule(rule_text: String):
	boss_rule_label.text = "Boss Rule: " + rule_text

func update_hand_dice_display(dice_info: Array):
	_update_dice_display_container(hand_dice_container, dice_info)

func update_field_dice_display(dice_info: Array):
	_update_dice_display_container(field_dice_container, dice_info)

func _update_dice_display_container(container: HBoxContainer, dice_data: Array):
	# Clear existing dice labels
	for child in container.get_children():
		child.queue_free()

	if dice_data.is_empty():
		var label = Label.new()
		label.text = "[Empty]"
		container.add_child(label)
	else:
		for die in dice_data:
			var label = Label.new()
			# Assuming die is a Dictionary with "color" (Color) and "value" (int)
			# Or a String like "D6 W (6)"
			if typeof(die) == TYPE_DICTIONARY:
				var color_name = ""
				if die.has("color"):
					# Simple color name mapping for display
					if die.color == Color.WHITE: color_name = "W"
					elif die.color == Color.BLACK: color_name = "K"
					elif die.color == Color.RED: color_name = "R"
					elif die.color == Color.GREEN: color_name = "G"
					elif die.color == Color.BLUE: color_name = "B"
					else: color_name = die.color.to_html(false)
				
				var value_text = ""
				if die.has("value"):
					value_text = str(die.value)
				
				label.text = "D" + str(die.get("sides", 6)) + " " + color_name + " (" + value_text + ")"
			else: # Assume it's already a formatted string
				label.text = str(die)
			
			container.add_child(label)

func on_submit_combo_pressed():
	submit_combo_pressed.emit()

func on_invest_pressed():
	invest_pressed.emit()

func _on_player_stats_updated(funds: int, submissions_left: int, investments_left: int):
	update_funds(funds)
	update_hand_invest_counts(submissions_left, investments_left)

func _on_help_button_pressed():
	help_panel.visible = true
	guide_text_label.text = """
[center][b][color=#FFD700]게임 가이드[/color][/b][/center]

[b]🎮 게임 개요[/b]
ColorComboDice2: The Journey는 Godot 4로 제작된 전략 주사위 게임입니다. 8단계의 여정을 통해 다양한 상대를 물리치고, 주사위 조합으로 점수를 획득하며, 핸드와 필드 주사위를 전략적으로 관리해야 합니다.

[b]🎯 기본 흐름[/b]
1.  [b]도전 시작[/b]: 목표 점수가 설정되며, 제한된 [b]제출[/b] 및 [b]투자[/b] 횟수가 주어집니다.
2.  [b]턴 시작[/b]: 핸드(패)의 주사위는 자동 리롤되며, 필드 주사위는 유지됩니다.
3.  [b]플레이어 행동[/b]:
	*   [b]조합 제출[/b]: 핸드/필드 주사위로 조합을 만들어 점수를 얻고, 사용된 주사위는 제거 후 핸드가 보충됩니다.
	*   [b]투자[/b]: 핸드의 주사위를 필드로 옮겨 다음 턴에 사용하며, 핸드가 보충됩니다.
4.  [b]승리/패배[/b]: 제한 내에 목표 점수 달성 시 승리, 실패 시 패배합니다.
5.  [b]보상 및 상점[/b]: 승리 시 자금을 얻어 조커 아이템을 구매할 수 있습니다.
6.  [b]진행[/b]: 모든 상대를 물리치면 다음 단계로 진행하며, 최종 보스 승리 시 게임에서 승리합니다.

[b]📊 점수 시스템[/b]
[code]최종 점수 = (기본 점수 합계) × (배율 합계) × 최종 배율[/code]
*   [b]기본 점수[/b]: 조합 및 조커 효과 점수.
*   [b]배율[/b]: 조커 효과 배율 합계.
*   [b]최종 배율[/b]: 모든 전역 조커 배율의 곱.

[b]🎲 조합 유형[/b]
*   [b]레인보우 런[/b]: 다른 색상의 연속된 값 (예: 1-2-3-4-5, 모두 다른 색상)
*   [b]레인보우 세트[/b]: 다른 색상의 동일한 값 (예: 3-3-3-3, 모두 다른 색상)
*   [b]단일 색상 런[/b]: 동일한 색상의 연속된 값 (예: 2-3-4-5, 모두 빨간색)
*   [b]단일 색상 세트[/b]: 동일한 색상의 동일한 값 (예: 5-5-5, 모두 파란색)
*   [b]컬러 풀 하우스[/b]: 한 가지 색상/값 3개 + 다른 색상/값 2개

[b]🕹️ 조작법[/b]
*   [b]마우스 좌클릭 + 길게 누르기[/b]: 주사위 컵 흔들기
*   [b]놓기[/b]: 주사위 쏟기
*   [b]C 키[/b]: 조합 선택 모드 토글
*   [b]마우스 좌클릭 (조합 선택 모드)[/b]: 조합할 주사위 선택/선택 해제
*   [b]마우스 우클릭 (조합 선택 모드)[/b]: 조합 확정
*   [b]V 키[/b]: 투자 선택 모드 토글
*   [b]마우스 좌클릭 (투자 선택 모드)[/b]: 투자할 주사위 선택/선택 해제
*   [b]마우스 우클릭 (투자 선택 모드)[/b]: 투자 확정
"""
	guide_text_label.scroll_to_line(0) # Scroll to top

func _on_close_help_button_pressed():
	help_panel.visible = false
