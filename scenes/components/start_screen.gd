extends Control
class_name StartScreen

signal start_game_requested

func _on_start_button_pressed() -> void:
	# 버튼 소리 재생 등을 추가할 수 있습니다.
	start_game_requested.emit()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
