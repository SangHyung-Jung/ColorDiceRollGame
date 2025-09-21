class_name AlleyBossRule
extends BossRule

func _init():
    id = "alley_boss"
    rule_name = "골목대장"
    description = "통행세"

func apply_effect(game_context: Dictionary) -> void:
    print("Alley Boss's rule applied: Dice used in combo will be permanently removed.")
    var game_manager = game_context.game_manager
    if game_manager != null:
        game_manager.dice_removed_for_combo.connect(self.process_dice_removal.bind(game_context))

func remove_effect(game_context: Dictionary) -> void:
    print("Alley Boss's rule removed.")
    var game_manager = game_context.game_manager
    if game_manager != null:
        game_manager.dice_removed_for_combo.disconnect(self.process_dice_removal.bind(game_context))

func process_dice_removal(dice_nodes: Array[Node3D], game_context: Dictionary) -> void:
    var dice_spawner = game_context.dice_spawner
    if dice_spawner != null:
        dice_spawner.remove_dice_permanently(dice_nodes)
