class_name JokerManager
extends Node

var active_jokers: Array = [] # Stores active joker items (e.g., from DataManager)
var _joker_effect_chance: float = 1.0 # Chance for joker effects to activate (1.0 = 100%)

func add_joker(joker_item: Dictionary) -> void:
    active_jokers.append(joker_item)
    print("Joker added: ", joker_item.name)

func remove_joker(joker_item: Dictionary) -> void:
    active_jokers.erase(joker_item)
    print("Joker removed: ", joker_item.name)

func get_active_jokers() -> Array:
    return active_jokers

func disable_rightmost_joker() -> void:
    if not active_jokers.is_empty():
        var rightmost_joker = active_jokers[active_jokers.size() - 1]
        rightmost_joker["is_active"] = false # Mark as inactive
        print("Rightmost joker disabled: ", rightmost_joker.name)

func enable_rightmost_joker() -> void:
    if not active_jokers.is_empty():
        var rightmost_joker = active_jokers[active_jokers.size() - 1]
        rightmost_joker["is_active"] = true # Mark as active
        print("Rightmost joker enabled: ", rightmost_joker.name)

func set_joker_effect_chance(chance: float) -> void:
    _joker_effect_chance = clamp(chance, 0.0, 1.0)
    print("Joker effect chance set to: ", _joker_effect_chance)

func get_joker_effect_chance() -> float:
    return _joker_effect_chance

# TODO: Implement methods to apply joker effects during gameplay
# For example, a method to get score multipliers, or extra submissions
