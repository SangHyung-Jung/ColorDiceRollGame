class_name HouseManagerRule
extends BossRule

func _init():
    id = "house_manager"
    rule_name = "하우스 매니저"
    description = "하우스 규칙"

func apply_effect(game_context: Dictionary) -> void:
    print("House Manager's rule applied: Rightmost joker disabled.")
    var joker_manager = game_context.joker_manager
    if joker_manager != null:
        joker_manager.disable_rightmost_joker()

func remove_effect(game_context: Dictionary) -> void:
    print("House Manager's rule removed.")
    var joker_manager = game_context.joker_manager
    if joker_manager != null:
        joker_manager.enable_rightmost_joker()
