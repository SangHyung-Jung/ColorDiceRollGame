class_name WarehouseOwnerRule
extends BossRule

func _init():
    id = "warehouse_owner"
    rule_name = "창고 주인"
    description = "보관료"

func apply_effect(game_context: Dictionary) -> void:
    print("Warehouse Owner's rule applied: Lose 10% of funds on scoring.")

func remove_effect(game_context: Dictionary) -> void:
    print("Warehouse Owner's rule removed.")

func modify_funds_earned(base_funds: int) -> int:
    return int(base_funds * 0.9) # 10% reduction