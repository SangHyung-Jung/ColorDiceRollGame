class_name MomRule
extends BossRule

func _init():
    id = "mom"
    rule_name = "엄마"
    description = "용돈 뺏기"

func apply_effect(game_context: Dictionary) -> void:
    # This rule affects fund calculation in JourneyManager
    # JourneyManager will check for active boss rule and apply reduction
    # No direct action needed here, just ensure JourneyManager knows this rule is active
    print("Mom's rule applied: Funds will be reduced.")

func remove_effect(game_context: Dictionary) -> void:
    print("Mom's rule removed.")

func modify_funds_earned(base_funds: int) -> int:
    return int(base_funds * 0.5) # 50% reduction