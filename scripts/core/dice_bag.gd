## 주사위 가방 관리 클래스
## 각 주사위의 색상과 특수 타입을 개별적으로 관리합니다.
class_name DiceBag
extends RefCounted

# 사용 가능한 주사위 색상들
const COLORS := ["W","K","R","G","B"]

# 가방에 들어있는 실제 주사위 목록: Array[Dictionary]
# 각 항목: { "color": "W", "type": 0 }
var _dice_list: Array = []

## 가방을 풀 세트로 초기화합니다 (각 색상 8개씩 기본 주사위)
func setup_full() -> void:
	_dice_list.clear()
	for c in COLORS:
		for i in range(8):
			add_die(c, 0) # 기본 타입(0) 주사위 추가

## 가방에 주사위를 추가합니다.
func add_die(color_key: String, type_index: int) -> void:
	_dice_list.append({
		"color": color_key,
		"type": type_index
	})

## 가방에 남은 전체 주사위 개수를 반환합니다
func total_left() -> int:
	return _dice_list.size()

## 특정 색상의 남은 주사위 개수를 반환합니다
func count_of(color_key: String) -> int:
	var count := 0
	for d in _dice_list:
		if d.color == color_key:
			count += 1
	return count

## 특정 색상 및 타입의 주사위 목록을 반환합니다 (UI 표시용)
func get_dice_by_color(color_key: String) -> Array:
	var out := []
	for d in _dice_list:
		if d.color == color_key:
			out.append(d)
	return out

## 색상 구분이 없는(Neutral) 특수 주사위 목록을 반환합니다
func get_neutral_dice() -> Array:
	var out := []
	for d in _dice_list:
		# Prism(8) 등 특정 타입은 색상 그룹에서 제외하고 따로 표시할 수 있음
		if d.type == 8: # Prism 예시
			out.append(d)
	return out

## 요청된 개수만큼 주사위를 뽑을 수 있는지 확인합니다
func can_draw(n: int) -> bool:
	return _dice_list.size() >= n

## 주사위를 한 개 뽑습니다 (색상+타입 정보 반환)
func draw_one_data() -> Dictionary:
	if _dice_list.is_empty():
		return {}
	
	var idx = randi() % _dice_list.size()
	return _dice_list.pop_at(idx)

## 여러 개의 주사위를 뽑습니다
func draw_many_data(n: int) -> Array:
	var out: Array = []
	n = min(n, _dice_list.size())
	for i in n:
		out.append(draw_one_data())
	return out

## 잘못 뽑은 주사위들을 가방에 다시 넣습니다
func undo_draw_data(dice_data_list: Array) -> void:
	for d in dice_data_list:
		_dice_list.append(d)

## [호환성 유지] 색상 키만 반환하는 기존 메서드
func draw_one(color_hint: String = "") -> String:
	var data = draw_one_data()
	return data.get("color", "")

func draw_many(n: int) -> Array:
	var out = []
	var data_list = draw_many_data(n)
	for d in data_list:
		out.append(d.color)
	return out

func get_counts() -> Dictionary:
	var counts = {"W":0,"K":0,"R":0,"G":0,"B":0}
	for d in _dice_list:
		if counts.has(d.color):
			counts[d.color] += 1
	return counts

func debug_print() -> void:
	print("[BAG] Total Left: ", _dice_list.size(), " Contents: ", get_counts())
