extends Control
class_name StartScreen

signal start_game_requested
signal joker_dictionary_requested

@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var joker_dictionary_button = $VBoxContainer/JokerDictionaryButton

func _ready():
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	else:
		push_error("StartButton not found in StartScreen!")

	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	else:
		push_error("QuitButton not found in StartScreen!")

	if joker_dictionary_button:
		joker_dictionary_button.pressed.connect(_on_joker_dictionary_button_pressed)
	else:
		push_error("JokerDictionaryButton not found in StartScreen!")

func _on_start_button_pressed() -> void:
	# 버튼 소리 재생 등을 추가할 수 있습니다.
	start_game_requested.emit()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_joker_dictionary_button_pressed() -> void:
	joker_dictionary_requested.emit()