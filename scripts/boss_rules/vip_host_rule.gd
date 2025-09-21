class_name VipHostRule
extends BossRule

func _init():
    id = "vip_host"
    rule_name = "VIP 호스트"
    description = "패 뒤섞기"

func apply_effect(game_context: Dictionary) -> void:
    print("VIP Host's rule applied: Hand dice colors will be randomized each turn.")

func remove_effect(game_context: Dictionary) -> void:
    print("VIP Host's rule removed.")

func apply_turn_effect(game_context: Dictionary) -> void:
    var game_manager = game_context.game_manager
    var dice_spawner = game_context.dice_spawner
    if game_manager == null or dice_spawner == null: return

    var hand_dice = game_manager.hand_dice
    var bag_colors = GameConstants.BAG_COLOR_MAP.values() # Get all possible colors

    for dice in hand_dice:
        if dice and is_instance_valid(dice):
            var random_color = bag_colors[randi() % bag_colors.size()]
            dice.set_dice_color(random_color) # Assuming Dice class has this method
            # Update the dice_def color in dice_spawner's dice_set if necessary
            # This might be complex, for now, rely on dice.dice_color for combo evaluation

    game_manager.hand_dice_updated.emit(game_manager._get_dice_display_data(game_manager.hand_dice)) # Update UI
    print("VIP Host randomized hand dice colors.")
