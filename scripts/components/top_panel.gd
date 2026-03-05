extends MarginContainer
class_name TopPanel

@onready var joker_slot_container: HBoxContainer = %JokerSlotContainer
@onready var item_slot_container: HBoxContainer = %ItemSlotContainer

func _ready():
	# 초기화 로직이 필요하다면 여기에 작성합니다.
	pass

func get_joker_slots() -> Array:
	return joker_slot_container.get_children()

func get_item_slots() -> Array:
	return item_slot_container.get_children()
