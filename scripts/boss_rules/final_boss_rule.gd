class_name FinalBossRule
extends BossRule

func _init():
    id = "final_boss"
    rule_name = "최후의 승부사"
    description = "마지막 승부"

func apply_effect(game_context: Dictionary) -> void:
    print("Final Boss's rule applied: Target score doubled, joker effects 50% chance.")
    var journey_manager = game_context.journey_manager
    var joker_manager = game_context.joker_manager

    if journey_manager != null:
        var current_opponent_data = journey_manager.STAGE_DATA[journey_manager.current_stage_idx].opponents[journey_manager.current_opponent_idx]
        current_opponent_data.target_score = int(current_opponent_data.target_score * 2.0) # Double target score
        # Update UI with new target score
        var game_ui = game_context.game_ui
        if game_ui != null:
            game_ui.update_stage_info(
                "Stage " + str(journey_manager.current_stage_idx + 1) + " - " + journey_manager.STAGE_DATA[journey_manager.current_stage_idx].name,
                current_opponent_data.name,
                current_opponent_data.target_score
            )

    if joker_manager != null:
        joker_manager.set_joker_effect_chance(0.5) # 50% chance

func remove_effect(game_context: Dictionary) -> void:
    print("Final Boss's rule removed.")
    var journey_manager = game_context.journey_manager
    var joker_manager = game_context.joker_manager

    if journey_manager != null:
        var current_opponent_data = journey_manager.STAGE_DATA[journey_manager.current_stage_idx].opponents[journey_manager.current_opponent_idx]
        current_opponent_data.target_score = int(current_opponent_data.target_score / 2.0) # Halve target score
        # Update UI with new target score
        var game_ui = game_context.game_ui
        if game_ui != null:
            game_ui.update_stage_info(
                "Stage " + str(journey_manager.current_stage_idx + 1) + " - " + journey_manager.STAGE_DATA[journey_manager.current_stage_idx].name,
                current_opponent_data.name,
                current_opponent_data.target_score
            )

    if joker_manager != null:
        joker_manager.set_joker_effect_chance(1.0) # Restore 100% chance
