class_name ParkKeeperRule
extends BossRule

var _fixed_dice: Node3D = null # Reference to the currently fixed die

func _init():
    id = "park_keeper"
    rule_name = "공원 관리인"
    description = "자리 정리"

func apply_effect(game_context: Dictionary) -> void:
    print("Park Keeper's rule applied: Random field die will be fixed each turn.")
    # JourneyManager will connect this rule to its turn_started signal

func remove_effect(game_context: Dictionary) -> void:
    if _fixed_dice != null:
        var game_manager = game_context.game_manager
        if game_manager != null:
            game_manager.set_dice_fixed(_fixed_dice, false) # Unfix the die
        _fixed_dice = null
    print("Park Keeper's rule removed.")

func apply_turn_effect(game_context: Dictionary) -> void:
    var game_manager = game_context.game_manager
    if game_manager == null: return

    # Unfix previously fixed die, if any
    if _fixed_dice != null:
        game_manager.set_dice_fixed(_fixed_dice, false)
        _fixed_dice = null

    var field_dice = game_manager.field_dice
    if not field_dice.is_empty():
        var random_idx = randi() % field_dice.size()
        _fixed_dice = field_dice[random_idx]
        game_manager.set_dice_fixed(_fixed_dice, true) # Fix the die
        print("Park Keeper fixed die: ", _fixed_dice.name)
    else:
        print("No field dice to fix for Park Keeper.")
