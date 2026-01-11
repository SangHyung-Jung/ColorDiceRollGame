extends PanelContainer
class_name JokerShopItem

signal item_purchased

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var unlock_label: Label = $MarginContainer/VBoxContainer/UnlockLabel
@onready var icon_texture: TextureRect = $MarginContainer/VBoxContainer/IconTexture
@onready var price_label: Label = $MarginContainer/VBoxContainer/PriceLabel
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyButton

# shop_screen.gd에서 이 변수에 데이터를 채워줍니다.
var joker_info: Dictionary

func _ready():
	# _ready()가 호출될 때는 @onready 변수들이 모두 준비된 상태입니다.
	if not joker_info:
		return

	name_label.text = joker_info.get("korean_name", "N/A")
	description_label.text = joker_info.get("description", "")
	unlock_label.text = "해금: " + joker_info.get("unlock_condition", "???")
	price_label.text = "Price: $" + str(joker_info.get("Price", 0))
	
	var image_path = joker_info.get("image_path", "")
	if image_path != "N/A" and FileAccess.file_exists(image_path):
		icon_texture.texture = load(image_path)
	
	# 여기서 해금 조건에 따라 구매 버튼을 활성화/비활성화 할 수 있습니다.
	# 예: if is_unlocked(joker_info):
	#         buy_button.disabled = false
	
func _on_buy_button_pressed():
	if Main.owned_jokers.size() >= 5:
		print("Joker inventory is full (Max 5).")
		return

	var price = joker_info.get("Price", 999)
	if Main.gold >= price:
		Main.gold -= price
		Main.owned_jokers.append(joker_info)
		print("Bought: %s for $%d. Remaining Gold: $%d" % [name_label.text, price, Main.gold])
		
		# 구매 후 버튼 비활성화 또는 상태 변경
		buy_button.disabled = true
		buy_button.text = "Owned"
		
		# 상위 노드(shop_screen)에 구매가 일어났음을 알림
		item_purchased.emit()
	else:
		print("Not enough gold to buy %s. Need $%d, have $%d" % [name_label.text, price, Main.gold])
