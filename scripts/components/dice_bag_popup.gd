extends Window

const DiceFaceImageScene = preload("res://scripts/components/dice_face_image.tscn")

const COLORS = [
	{"key": "W", "name": "하얀색"},
	{"key": "K", "name": "검은색"},
	{"key": "R", "name": "빨간색"},
	{"key": "G", "name": "초록색"},
	{"key": "B", "name": "파란색"},
]

var ui_nodes: Dictionary = {} # { "W": {"image": node, "label": node}, ... }

func _ready():
	close_requested.connect(hide)
	
	var grid = get_node("MarginContainer/GridContainer")
	
	for color_info in COLORS:
		var key = color_info["key"]
		
		# Create Dice Image
		var image = DiceFaceImageScene.instantiate()
		image.custom_minimum_size = Vector2(60, 60)
		image.set_face(6, TextureCache.get_atlas(key))
		grid.add_child(image)
		
		# Create Label
		var label = Label.new()
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("font_size", 24)
		grid.add_child(label)
		
		ui_nodes[key] = {"image": image, "label": label}

func update_counts(dice_bag: DiceBag):
	for color_key in ui_nodes:
		var nodes = ui_nodes[color_key]
		var count = dice_bag.count_of(color_key)
		nodes["label"].text = ": " + str(count)
