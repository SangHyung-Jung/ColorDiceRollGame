extends Node

var boss_rules_data: Dictionary = {}
var joker_items_data: Dictionary = {}

func _ready():
	_load_boss_rules()
	_load_joker_items()

func _load_json_file(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Failed to open JSON file: ", path)
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var json_data = JSON.parse_string(content)
	if json_data == null:
		printerr("Failed to parse JSON from file: ", path)
		return {}
		
	return json_data

func _load_boss_rules():
	var data = _load_json_file("res://data/boss_rules.json")
	if data is Array:
		for rule_dict in data:
			if rule_dict.has("id") and rule_dict.has("script_path"):
				var script_path = rule_dict.script_path
				var script = load(script_path)
				if script and script is GDScript:
					var boss_rule_instance = script.new()
					# Ensure the instance has the properties from the JSON
					boss_rule_instance.id = rule_dict.id
					boss_rule_instance.rule_name = rule_dict.name
					boss_rule_instance.description = rule_dict.description
					boss_rules_data[rule_dict.id] = boss_rule_instance
				else:
					printerr("Failed to load script for boss rule ID: ", rule_dict.id, " at path: ", script_path)
			else:
				printerr("Boss rule without 'id' or 'script_path' found: ", rule_dict)
	else:
		printerr("boss_rules.json is not an Array.")

func _load_joker_items():
	var data = _load_json_file("res://data/joker_items.json")
	if data is Array:
		for item in data:
			if item.has("id"):
				joker_items_data[item.id] = item
			else:
				printerr("Joker item without 'id' found: ", item)
	else:
		printerr("joker_items.json is not an Array.")

func get_boss_rule_by_id(id: String) -> BossRule:
	return boss_rules_data.get(id, null)

func get_joker_item_by_id(id: String) -> Dictionary:
	return joker_items_data.get(id, {})
