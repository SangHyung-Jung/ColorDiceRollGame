extends Control
class_name JokerDictionary

signal back_requested

@onready var back_button = $"Panel/VBoxContainer/Header/BackToStartButton"
@onready var joker_list_container = $"Panel/VBoxContainer/ScrollContainer/JokerList"

const JOKER_DATA_PATH = "res://jokers.csv"
const JOKER_DISPLAY_SCENE = preload("res://scenes/components/joker_display_item.tscn") # Will create this next

func _ready():
	back_button.pressed.connect(_on_back_button_pressed)
	_load_and_display_jokers()

func _on_back_button_pressed():
	back_requested.emit()

func _load_and_display_jokers():
	var file = FileAccess.open(JOKER_DATA_PATH, FileAccess.READ)
	if file == null:
		print("Error opening joker data file: ", FileAccess.get_open_error())
		return

	# Read header
	var header = file.get_csv_line() 
	if header.is_empty():
		print("Joker data file is empty or malformed.")
		return
		
	var id_idx = header.find("id")
	var korean_name_idx = header.find("korean_name")
	var english_name_idx = header.find("english_name")
	var image_path_idx = header.find("image_path")
	var description_idx = header.find("description")
	var unlock_condition_idx = header.find("unlock_condition")
	var tier_idx = header.find("Tier")
	var price_idx = header.find("Price")

	if id_idx == -1 or korean_name_idx == -1 or image_path_idx == -1 or description_idx == -1:
		print("Joker data file header missing required columns.")
		return

	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.is_empty() or line.size() < max(id_idx, korean_name_idx, image_path_idx, description_idx) + 1:
			continue # Skip empty or malformed lines

		var joker_data = {
			"id": line[id_idx],
			"korean_name": line[korean_name_idx],
			"english_name": line[english_name_idx],
			"image_path": line[image_path_idx],
			"description": line[description_idx],
			"unlock_condition": line[unlock_condition_idx],
			"Tier": line[tier_idx],
			"Price": line[price_idx],
		}
		_add_joker_to_display(joker_data)
	
	file.close()

func _add_joker_to_display(joker_data: Dictionary):
	var joker_item = JOKER_DISPLAY_SCENE.instantiate()
	joker_list_container.add_child(joker_item)
	joker_item.set_joker_data(joker_data) # This function will be implemented in joker_display_item.gd
