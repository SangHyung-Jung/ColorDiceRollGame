extends RefCounted
class_name ComboRules

# meta용 기본 색 매핑 (bag_key → Color)
const BAG_COLOR_MAP := {
	"W": Color.WHITE, "K": Color.BLACK, "R": Color.RED, "G": Color.GREEN, "B": Color.BLUE
}

# --- 데이터 클래스 ---
class DieData:
	var color: Color = Color.WHITE
	var value: int = -1
	var id: int = -1

	static func from_node(n: Node, roll_value: int = -999) -> DieData:
		var d := DieData.new()
		d.id = int(n.get_instance_id())

		var col = n.get("dice_color")
		if col == null:
			if n.has_meta("bag_key"):
				var key := str(n.get_meta("bag_key"))
				if BAG_COLOR_MAP.has(key):
					col = BAG_COLOR_MAP[key]
		d.color = col if col != null else Color.WHITE

		if roll_value != -999:
			d.value = roll_value
		else:
			var v = n.get("value")
			d.value = int(v) if v != null else -1
		return d

class ComboResult:
	var ok: bool = false
	var combo_name: String = ""
	var points: int = 0
	var reason: String = ""

# --- 조합 정의 ---
const COMBO_DEFINITIONS = [
	{"name": "Yacht", "is_color": true, "condition": "is_n_of_a_kind", "params": [5], "base_score": 250, "multiplier": 10},
	{"name": "Yacht", "is_color": false, "condition": "is_n_of_a_kind", "params": [5], "base_score": 150, "multiplier": 8},
	{"name": "라지 스트레이트", "is_color": true, "condition": "is_straight", "params": [5], "base_score": 120, "multiplier": 6},
	{"name": "라지 스트레이트", "is_color": false, "condition": "is_straight", "params": [5], "base_score": 70, "multiplier": 5},
	{"name": "포카드", "is_color": true, "condition": "is_n_of_a_kind", "params": [4], "base_score": 100, "multiplier": 5},
	{"name": "포카드", "is_color": false, "condition": "is_n_of_a_kind", "params": [4], "base_score": 60, "multiplier": 4},
	{"name": "풀하우스", "is_color": true, "condition": "is_full_house", "params": [], "base_score": 90, "multiplier": 5},
	{"name": "풀하우스", "is_color": false, "condition": "is_full_house", "params": [], "base_score": 50, "multiplier": 4},
	{"name": "스몰 스트레이트", "is_color": true, "condition": "is_straight", "params": [4], "base_score": 70, "multiplier": 4},
	{"name": "스몰 스트레이트", "is_color": false, "condition": "is_straight", "params": [4], "base_score": 40, "multiplier": 3},
	{"name": "트리플", "is_color": true, "condition": "is_n_of_a_kind", "params": [3], "base_score": 50, "multiplier": 3},
	{"name": "트리플", "is_color": false, "condition": "is_n_of_a_kind", "params": [3], "base_score": 30, "multiplier": 2},
	{"name": "투페어", "is_color": true, "condition": "is_two_pair", "params": [], "base_score": 40, "multiplier": 3},
	{"name": "투페어", "is_color": false, "condition": "is_two_pair", "params": [], "base_score": 20, "multiplier": 2},
	{"name": "미니 스트레이트", "is_color": true, "condition": "is_straight", "params": [3], "base_score": 25, "multiplier": 3},
	{"name": "미니 스트레이트", "is_color": false, "condition": "is_straight", "params": [3], "base_score": 15, "multiplier": 2},
]


# --- 조합 평가 ---
func eval_combo(dice: Array) -> ComboResult:
	var res := ComboResult.new()
	
	for definition in COMBO_DEFINITIONS:
		var condition_func = definition["condition"]
		var params = definition.get("params", [])
		
		var args = [dice] + params
		if callv(condition_func, args):
			var is_color_combo = definition.get("is_color", false)
			if is_color_combo and not _all_same_color(dice):
				continue

			res.ok = true
			res.combo_name = definition["name"]
			if is_color_combo:
				res.combo_name += " (단일 색상)"
			else:
				res.combo_name += " (다색상)"
			
			var base_score = definition["base_score"]
			var multiplier = definition["multiplier"]
			var sum_of_values = 0
			for d in dice:
				sum_of_values += d.value
				
			res.points = (base_score + sum_of_values) * multiplier
			return res

	res.ok = false
	res.reason = "정의된 조합이 아님"
	return res

# --- 조합 조건 헬퍼 함수 ---

func is_n_of_a_kind(dice: Array, n: int) -> bool:
	if dice.size() != n:
		return false
	var counts = _get_value_counts(dice)
	for count in counts.values():
		if count >= n:
			return true
	return false

func is_two_pair(dice: Array) -> bool:
	if dice.size() != 4:
		return false
	var counts = _get_value_counts(dice)
	var pair_count = 0
	for count in counts.values():
		if count >= 2:
			pair_count += 1
	return pair_count == 2

func is_full_house(dice: Array) -> bool:
	if dice.size() != 5:
		return false
	var counts = _get_value_counts(dice)
	var has_three = false
	var has_two = false
	for count in counts.values():
		if count == 3:
			has_three = true
		if count == 2:
			has_two = true
	return has_three and has_two

func is_straight(dice: Array, min_length: int) -> bool:
	if dice.size() != min_length:
		return false
	var vals = _sorted_vals(dice)
	var unique_vals = []
	if not vals.is_empty():
		unique_vals.append(vals[0])
		for i in range(1, vals.size()):
			if vals[i] > vals[i-1]:
				unique_vals.append(vals[i])
	
	if unique_vals.size() != min_length:
		return false

	for i in range(1, unique_vals.size()):
		if unique_vals[i] != unique_vals[i-1] + 1:
			return false
	return true

# --- 내부 유틸리티 함수 ---

func _get_value_counts(dice: Array) -> Dictionary:
	var counts = {}
	for d in dice:
		if not counts.has(d.value):
			counts[d.value] = 0
		counts[d.value] += 1
	return counts

func _sorted_vals(dice: Array) -> Array:
	var vals: Array = []
	for d in dice: vals.append(int(d.value))
	vals.sort()
	return vals

func _all_same_color(dice: Array) -> bool:
	if dice.is_empty(): return false
	var c: Color = dice[0].color
	for d in dice:
		if d.color != c: return false
	return true
