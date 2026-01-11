extends HBoxContainer
class_name JokerInventory

# 이 컨트롤은 5개의 조커 슬롯 UI를 관리합니다.

@onready var slots: Array[TextureRect] = [
	$Slot1/Background/Icon,
	$Slot2/Background/Icon,
	$Slot3/Background/Icon,
	$Slot4/Background/Icon,
	$Slot5/Background/Icon,
]

## 소유한 조커 목록을 받아서 UI를 업데이트합니다.
func update_display(owned_jokers: Array) -> void:
	for i in range(slots.size()):
		var slot_icon: TextureRect = slots[i]
		if i < owned_jokers.size():
			var joker = owned_jokers[i]
			var image_path = joker.get("image_path", "")
			if image_path != "N/A" and FileAccess.file_exists(image_path):
				slot_icon.texture = load(image_path)
			else:
				slot_icon.texture = null # 이미지가 없는 경우
		else:
			# 소유하지 않은 슬롯은 비웁니다.
			slot_icon.texture = null
