class_name BossRule
extends Resource

# Unique ID for the boss rule (matches JSON ID)
@export var id: String = ""
# Display name of the rule
@export var rule_name: String = ""
# Description of the rule's effect
@export var description: String = ""

# Virtual method to apply the boss rule's effect
# game_context: Dictionary containing references to relevant managers (GameManager, ScoreManager, etc.)
func apply_effect(game_context: Dictionary) -> void:
    push_warning("apply_effect not implemented for BossRule: ", id)

# Virtual method to remove the boss rule's effect
# game_context: Dictionary containing references to relevant managers
func remove_effect(game_context: Dictionary) -> void:
    push_warning("remove_effect not implemented for BossRule: ", id)