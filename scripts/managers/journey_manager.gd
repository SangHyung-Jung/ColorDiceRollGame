class_name JourneyManager
extends Node

signal stage_changed(stage_name: String, opponent_name: String, target_score: int)
signal player_stats_updated(funds: int, submissions_left: int, investments_left: int)
signal boss_rule_applied(rule_text: String)
signal game_over(won: bool)
signal turn_started() # New signal for turn start
signal turn_ended() # New signal for turn end

# === Game Data ===
var current_stage_idx: int = 0
var current_opponent_idx: int = 0
var player_funds: int = 0
var submissions_left: int = 0
var investments_left: int = 0
var _active_boss_rule_id: String = "" # Stores the ID of the currently active boss rule
var _active_boss_rule_object: BossRule = null # Stores the instance of the active boss rule script
var _game_context: Dictionary = {} # Stores references to other managers

# === Game Design Data (from GDD) ===
const STAGE_DATA = [
	{
		"name": "집",
		"opponents": [
			{"name": "상대 1", "target_score": 300, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 450, "boss_rule_id": ""},
			{"name": "엄마", "target_score": 450, "boss_rule_id": "mom"}
		]
	},
	{
		"name": "동네 공원",
		"opponents": [
			{"name": "상대 1", "target_score": 800, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 1200, "boss_rule_id": ""},
			{"name": "공원 관리인", "target_score": 1200, "boss_rule_id": "park_keeper"}
		]
	},
	{
		"name": "뒷골목",
		"opponents": [
			{"name": "상대 1", "target_score": 2000, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 3200, "boss_rule_id": ""},
			{"name": "골목대장", "target_score": 3200, "boss_rule_id": "alley_boss"}
		]
	},
	{
		"name": "창고",
		"opponents": [
			{"name": "상대 1", "target_score": 5000, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 8000, "boss_rule_id": ""},
			{"name": "창고 주인", "target_score": 8000, "boss_rule_id": "warehouse_owner"}
		]
	},
	{
		"name": "하우스",
		"opponents": [
			{"name": "상대 1", "target_score": 11000, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 18000, "boss_rule_id": ""},
			{"name": "하우스 매니저", "target_score": 18000, "boss_rule_id": "house_manager"}
		]
	},
	{
		"name": "VIP 라운지",
		"opponents": [
			{"name": "상대 1", "target_score": 25000, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 40000, "boss_rule_id": ""},
			{"name": "VIP 호스트", "target_score": 40000, "boss_rule_id": "vip_host"}
		]
	},
	{
		"name": "비밀 카지노",
		"opponents": [
			{"name": "상대 1", "target_score": 55000, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 90000, "boss_rule_id": ""},
			{"name": "카지노 지배인", "target_score": 90000, "boss_rule_id": "casino_director"}
		]
	},
	{
		"name": "정상의 무대",
		"opponents": [
			{"name": "상대 1", "target_score": 120000, "boss_rule_id": ""},
			{"name": "상대 2", "target_score": 200000, "boss_rule_id": ""},
			{"name": "최후의 승부사", "target_score": 400000, "boss_rule_id": "final_boss"}
		]
	}
]

func initialize(game_context: Dictionary):
	current_stage_idx = 0
	current_opponent_idx = 0
	player_funds = 0
	submissions_left = 4 # Initial value from GDD
	investments_left = 5 # Initial value from GDD
	_game_context = game_context # Store the context
	_update_ui_stats()
	_start_current_opponent() # Start the first opponent after context is set

func get_game_context() -> Dictionary:
	return _game_context

func _start_current_opponent():
	var stage = STAGE_DATA[current_stage_idx]
	var opponent = stage.opponents[current_opponent_idx]
	
	var stage_name = "Stage " + str(current_stage_idx + 1) + " - " + stage.name
	var opponent_name = opponent.name
	var target_score = opponent.target_score
	var boss_rule_id = opponent.boss_rule_id # Get the ID
	
	# Remove effect of previous boss rule if active
	if _active_boss_rule_object != null:
		_active_boss_rule_object.remove_effect(_game_context) # Pass game context
		_active_boss_rule_object = null # Clear reference

	_active_boss_rule_id = boss_rule_id # Set the active boss rule ID
	
	stage_changed.emit(stage_name, opponent_name, target_score)
	
	if not boss_rule_id.is_empty():
		var boss_rule_data = DataManager.get_boss_rule_by_id(boss_rule_id)
		if boss_rule_data != null:
			_active_boss_rule_object = boss_rule_data
			boss_rule_applied.emit(_active_boss_rule_object.rule_name + ": " + _active_boss_rule_object.description)
			_active_boss_rule_object.apply_effect(_game_context) # Apply new rule
			
			# Connect turn_started to apply_turn_effect if the rule has it
			if _active_boss_rule_object.has_method("apply_turn_effect"):
				turn_started.connect(_active_boss_rule_object.apply_turn_effect.bind(_game_context))
			
			# Connect turn_ended to apply_turn_end_effect if the rule has it
			if _active_boss_rule_object.has_method("apply_turn_end_effect"):
				turn_ended.connect(_active_boss_rule_object.apply_turn_end_effect.bind(_game_context))
		else:
			printerr("Boss rule object for ID ", boss_rule_id, " not found in DataManager.")
			boss_rule_applied.emit("") # Clear display if rule not found
	else:
		boss_rule_applied.emit("") # Clear boss rule display for normal opponents
	
	# Reset player's submission/investment counts for new opponent
	submissions_left = 4 # Default for now, will need to be dynamic
	investments_left = 5 # Default for now, will need to be dynamic
	_update_ui_stats()
	turn_started.emit() # Emit turn started after opponent setup

func process_submission(current_total_score: int) -> void:
	submissions_left -= 1
	var target_score = STAGE_DATA[current_stage_idx].opponents[current_opponent_idx].target_score

	if current_total_score >= target_score:
		_process_win(current_total_score)
	elif submissions_left <= 0:
		_process_lose()
	
	# Simple fund calculation placeholder for now
	player_funds += current_total_score / 10 
	_update_ui_stats()
	turn_started.emit() # Emit turn started after submission
	turn_ended.emit() # Emit turn ended after submission

func process_investment() -> void:
	investments_left -= 1
	if investments_left <= 0 and submissions_left <= 0:
		_process_lose()
	_update_ui_stats()
	turn_started.emit() # Emit turn started after investment
	turn_ended.emit() # Emit turn ended after investment

func _update_ui_stats():
	player_stats_updated.emit(player_funds, submissions_left, investments_left)

func get_current_stage_info() -> Dictionary:
	var stage = STAGE_DATA[current_stage_idx]
	var opponent = stage.opponents[current_opponent_idx]
	return {
		"stage_name": "Stage " + str(current_stage_idx + 1) + " - " + stage.name,
		"opponent_name": opponent.name,
		"target_score": opponent.target_score,
		"boss_rule_id": opponent.boss_rule_id
	}

func get_player_stats() -> Dictionary:
	return {
		"funds": player_funds,
		"submissions_left": submissions_left,
		"investments_left": investments_left
	}

func get_modified_funds_earned(base_funds: int) -> int:
	var modified_funds = base_funds
	if _active_boss_rule_object != null and _active_boss_rule_object.has_method("modify_funds_earned"):
		modified_funds = _active_boss_rule_object.modify_funds_earned(base_funds)
	return modified_funds

func _process_win(final_score: int):
	var base_funds_earned = final_score / 50 # Placeholder for funds calculation
	var funds_earned = get_modified_funds_earned(base_funds_earned) # Apply boss rule modification

	# Remove hardcoded Mom rule
	# if _active_boss_rule_id == "mom":
	#     funds_earned *= 0.5 # "용돈 뺏기" - 50% 감소 (example)
	#     print("Mom's rule applied! Funds reduced.")

	player_funds += funds_earned
	print("Opponent defeated! Earned $", funds_earned, ". Total funds: $", player_funds)
	
	current_opponent_idx += 1
	if current_opponent_idx >= STAGE_DATA[current_stage_idx].opponents.size():
		current_opponent_idx = 0
		current_stage_idx += 1
		if current_stage_idx >= STAGE_DATA.size(): # CORRECTED LINE
			game_over.emit(true) # Final win
			return
	_start_current_opponent()
	_update_ui_stats() # Update UI after advancing

func _process_lose():
	print("You lost the challenge!")
	game_over.emit(false)
	_update_ui_stats() # Update UI after losing
