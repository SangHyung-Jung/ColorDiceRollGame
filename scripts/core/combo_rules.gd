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
	var type: int = 0 # [추가] 주사위 타입 (0: 일반, 4: Faceless, 8: Prism 등)

	static func from_node(n: Node, roll_value: int = -999) -> DieData:
		var d := DieData.new()
		d.id = int(n.get_instance_id())
		d.type = n.get("current_dice_type") if "current_dice_type" in n else 0 # [추가]

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
	var base_score: int = 0
	var dice_sum: int = 0
	var multiplier: int = 0

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
				
			res.base_score = base_score
			res.dice_sum = sum_of_values
			res.multiplier = multiplier
			res.points = (base_score + sum_of_values) * multiplier
			
			res.ok = true # 순서 중요: 데이터 다 채우고 true 설정
			return res

	res.ok = false
	res.reason = "정의된 조합이 아님"
	return res

# --- 조합 조건 헬퍼 함수 ---

func is_n_of_a_kind(dice: Array, n: int) -> bool:
	if dice.size() != n:
		return false
	
	var faceless_count = 0
	var other_dice = []
	for d in dice:
		if d.type == 4: # Faceless
			faceless_count += 1
		else:
			other_dice.append(d)
			
	if faceless_count == n: return true # 모두 와일드카드면 성공
	
	var counts = _get_value_counts(other_dice)
	for count in counts.values():
		if count + faceless_count >= n:
			return true
	return false

func is_two_pair(dice: Array) -> bool:
	if dice.size() != 4:
		return false
		
	var faceless_count = 0
	var other_dice = []
	for d in dice:
		if d.type == 4: faceless_count += 1
		else: other_dice.append(d)
		
	var counts = _get_value_counts(other_dice)
	var pair_info = [] # 각 숫자의 개수 리스트
	for count in counts.values():
		pair_info.append(count)
	pair_info.sort_custom(func(a, b): return a > b) # 큰 순서대로 정렬
	
	# 로직: 가장 많은 것부터 페어로 만들고 남은 faceless로 다음 페어를 보충
	var pairs_found = 0
	for i in range(pair_info.size()):
		var c = pair_info[i]
		if c >= 2:
			pairs_found += 1
		elif c == 1 and faceless_count >= 1:
			pairs_found += 1
			faceless_count -= 1
			
	# 남은 faceless가 2개 이상이면 새로운 페어 가능
	pairs_found += faceless_count / 2
	
	return pairs_found >= 2

func is_full_house(dice: Array) -> bool:
	if dice.size() != 5:
		return false
		
	var faceless_count = 0
	var other_dice = []
	for d in dice:
		if d.type == 4: faceless_count += 1
		else: other_dice.append(d)
		
	if faceless_count >= 2: return true # 와일드카드 2개면 무조건 풀하우스 가능 (3+2)
	
	var counts = _get_value_counts(other_dice)
	var vals = counts.values()
	vals.sort_custom(func(a, b): return a > b)
	
	if faceless_count == 1:
		# 1개 있을 때: (2,2) -> (3,2), (3,1) -> (3,2)
		if vals.size() >= 2:
			if (vals[0] >= 2 and vals[1] >= 2) or (vals[0] >= 3 and vals[1] >= 1):
				return true
		return false
	else:
		# 0개 있을 때: 정석 풀하우스
		return vals.size() == 2 and vals[0] >= 3 and vals[1] >= 2

func is_straight(dice: Array, min_length: int) -> bool:
	if dice.size() != min_length:
		return false
		
	var faceless_count = 0
	var unique_vals = []
	for d in dice:
		if d.type == 4:
			faceless_count += 1
		elif not d.value in unique_vals:
			unique_vals.append(d.value)
	
	unique_vals.sort()
	
	# 중복된 숫자가 너무 많아서 스트레이트가 불가능한 경우 (faceless로도 못 메꿈)
	if unique_vals.size() + faceless_count < min_length:
		return false
		
	# 스트레이트 체크 (가장 작은 값부터 시작해서 빈 공간을 faceless로 채움)
	if unique_vals.is_empty(): return true # 모두 faceless
	
	var needed_total = 0
	for i in range(1, unique_vals.size()):
		needed_total += (unique_vals[i] - unique_vals[i-1] - 1)
		
	return needed_total <= faceless_count

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
	
	# Prism(8번)이 아닌 첫 번째 주사위의 색상을 기준으로 잡음
	var base_color: Color = Color.TRANSPARENT
	for d in dice:
		if d.type != 8: # Prism이 아니면
			if base_color == Color.TRANSPARENT:
				base_color = d.color
			elif d.color != base_color:
				return false
				
	return true
