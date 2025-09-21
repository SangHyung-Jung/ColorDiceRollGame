class_name CasinoDirectorRule
extends BossRule

func _init():
    id = "casino_director"
    rule_name = "카지노 지배인"
    description = "시간 압박"

func apply_effect(game_context: Dictionary) -> void:
    print("Casino Director's rule applied: Target score will increase each turn.")
    var journey_manager = game_context.journey_manager
    if journey_manager != null:
        journey_manager.turn_ended.connect(self.apply_turn_end_effect.bind(game_context))

func remove_effect(game_context: Dictionary) -> void:
    print("Casino Director's rule removed.")
    var journey_manager = game_context.journey_manager
    if journey_manager != null:
        journey_manager.turn_ended.disconnect(self.apply_turn_end_effect.bind(game_context))

func apply_turn_end_effect(game_context: Dictionary) -> void:
    var journey_manager = game_context.journey_manager
    if journey_manager == null: return

    var current_opponent_data = journey_manager.STAGE_DATA[journey_manager.current_stage_idx].opponents[journey_manager.current_opponent_idx]
    current_opponent_data.target_score = int(current_opponent_data.target_score * 1.05) # Increase by 5%
    
    # Update UI with new target score
    var game_ui = game_context.game_ui
    if game_ui != null:
        game_ui.update_stage_info(
            "Stage " + str(journey_manager.current_stage_idx + 1) + " - " + journey_manager.STAGE_DATA[journey_manager.current_stage_idx].name,
            current_opponent_data.name,
            current_opponent_data.target_score
        )
    print("Casino Director: Target score increased to ", current_opponent_data.target_score)
