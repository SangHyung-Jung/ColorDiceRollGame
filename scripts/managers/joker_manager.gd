extends Node

# JokerManager.gd

var joker_data: Array[Dictionary] = []
const JOKERS_CSV_PATH = "res://jokers.csv"

func _ready() -> void:
	_load_joker_data()

func _load_joker_data() -> void:
	var file = FileAccess.open(JOKERS_CSV_PATH, FileAccess.READ)
	if not FileAccess.file_exists(JOKERS_CSV_PATH):
		push_error("Joker data file not found at: " + JOKERS_CSV_PATH)
		return

	# 헤더 행 건너뛰기
	var headers = file.get_csv_line()

	while not file.eof_reached():
		var line_data = file.get_csv_line()
		# 빈 줄이거나 데이터가 부족한 경우 건너뛰기
		if line_data.size() < headers.size():
			continue

		var joker_info: Dictionary = {}
		for i in range(headers.size()):
			var key = headers[i].strip_edges()
			var value = line_data[i]
			# id와 Price는 정수형으로 변환
			if key == "id" or key == "Price":
				if value.is_valid_int():
					value = int(value)
				else:
					value = 0 # 숫자가 아닐 경우 기본값 0
			joker_info[key] = value
		
		joker_data.append(joker_info)
	
	print("Loaded %d jokers." % joker_data.size())

## 모든 조커 목록을 반환합니다.
func get_all_jokers() -> Array[Dictionary]:
	return joker_data

## ID로 특정 조커의 정보를 찾아 반환합니다.
## @param id: 찾으려는 조커의 ID
## @return: 조커 정보를 담은 Dictionary, 없으면 null
func get_joker_by_id(id: int) -> Dictionary:
	for joker in joker_data:
		if joker.has("id") and joker["id"] == id:
			return joker
	return {}

## 조커의 판매 가격을 계산합니다 (구매가의 50%, 올림).
func get_sell_price(buy_price: int) -> int:
	return int(ceil(float(buy_price) * 0.5))

func get_random_jokers(count: int) -> Array:
	var selected_jokers = []
	if joker_data.is_empty():
		return []

	# Make a copy to avoid modifying the original array
	var shuffled_jokers = joker_data.duplicate()
	shuffled_jokers.shuffle()
	
	# Get the requested number of jokers
	var num_to_get = min(count, shuffled_jokers.size())
	for i in range(num_to_get):
		selected_jokers.append(shuffled_jokers[i])
		
	return selected_jokers
