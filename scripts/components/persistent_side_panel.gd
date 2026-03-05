extends MarginContainer
class_name PersistentSidePanel

@onready var stage_label: Label = %StageLabel
@onready var target_score_label: Label = %TargetScoreLabel
@onready var current_score_label: Label = %CurrentScoreLabel
@onready var gold_label: Label = %GoldLabel
@onready var turns_left_label: Label = %TurnsLeftLabel
@onready var invests_left_label: Label = %InvestsLeftLabel
@onready var view_dice_bag_button: Button = %ViewDiceBagButton

# Game specific
@onready var score_calc_box: VBoxContainer = %ScoreCalcBox
@onready var combo_name_label: Label = %ComboNameLabel
@onready var score_label: Label = %ScoreLabel
@onready var multiplier_label: Label = %MultiplierLabel
@onready var turn_score_label: Label = %TurnScoreLabel

# Shop specific
@onready var joker_inventory: HBoxContainer = %JokerInventory

signal dice_bag_requested

func _ready():
	# Initial state
	show_game_ui()
	view_dice_bag_button.pressed.connect(func(): dice_bag_requested.emit())

func show_game_ui():
	score_calc_box.visible = true
	joker_inventory.visible = false

func show_shop_ui():
	score_calc_box.visible = false
	joker_inventory.visible = true

func update_stage(stage_num: int):
	stage_label.text = "Stage: %d" % stage_num

func update_stage_text(text: String):
	stage_label.text = text

func update_target_score(score: int):
	target_score_label.text = "Target Score: %d" % score

func update_current_score(score: int):
	current_score_label.text = "Current Score: %d" % score

func update_gold(amount: int):
	gold_label.text = "Gold: $%d" % amount

func update_turns_left(count: int):
	turns_left_label.text = "Left Turns: %d" % count

func update_invests_left(count: int):
	invests_left_label.text = "Left Invests: %d" % count

func update_joker_inventory(jokers: Array):
	if joker_inventory.has_method("update_display"):
		joker_inventory.update_display(jokers)

func reset_score_calc():
	combo_name_label.text = "None"
	combo_name_label.modulate = Color.WHITE
	score_label.text = "0"
	score_label.modulate = Color.WHITE
	multiplier_label.text = "0"
	multiplier_label.modulate = Color.WHITE
	turn_score_label.text = " "
