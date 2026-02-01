extends HBoxContainer
class_name JokerDisplayItem

@onready var joker_image = $JokerImage
@onready var name_label = $VBoxContainer/NameLabel
@onready var description_label = $VBoxContainer/DescriptionLabel
@onready var unlock_condition_label = $VBoxContainer/UnlockConditionLabel
@onready var tier_label = $VBoxContainer/TierLabel
@onready var price_label = $VBoxContainer/PriceLabel

func set_joker_data(data: Dictionary):
	# Load image
	var image_path = data.get("image_path", "")
	if image_path and ResourceLoader.exists(image_path):
		joker_image.texture = load(image_path)
	else:
		joker_image.texture = null # Or a placeholder image

	name_label.text = "%s (%s)" % [data.get("korean_name", "N/A"), data.get("english_name", "N/A")]
	description_label.text = data.get("description", "N/A")
	unlock_condition_label.text = "Unlock: %s" % data.get("unlock_condition", "N/A")
	tier_label.text = "Tier: %s" % data.get("Tier", "N/A")
	price_label.text = "Price: %s" % data.get("Price", "N/A")