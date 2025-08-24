extends RefCounted
class_name ComboRules

enum ComboType { RAINBOW_RUN, RAINBOW_SET, SINGLE_COLOR_RUN, COLOR_FULL_HOUSE, SINGLE_COLOR_SET }

static func combo_name(t: int) -> String:
	match t:
		ComboType.RAINBOW_RUN: return "레인보우 런"
		ComboType.RAINBOW_SET: return "레인보우 셋"
		ComboType.SINGLE_COLOR_RUN: return "싱글 컬러 런"
		ComboType.COLOR_FULL_HOUSE: return "컬러 풀하우스"
		ComboType.SINGLE_COLOR_SET: return "싱글 컬러 셋"
		_: return "알 수 없음"

const SCORE_TABLE := {
	ComboType.RAINBOW_RUN:        {3:2, 4:4, 5:7, 6:11},
	ComboType.RAINBOW_SET:        {3:3, 4:6, 5:10, 6:15},
	ComboType.SINGLE_COLOR_RUN:   {3:5, 4:9, 5:15, 6:23},
	ComboType.COLOR_FULL_HOUSE:   {5:19},
	ComboType.SINGLE_COLOR_SET:   {3:8, 4:14, 5:23, 6:35},
}

const FULLHOUSE_REQUIRE_DIFFERENT_VALUES := false

# meta용 기본 색 매핑 (bag_key → Color)
const BAG_COLOR_MAP := {
	"W": Color.WHITE, "K": Color.BLACK, "R": Color.RED, "G": Color.GREEN, "B": Color.BLUE
}

class DieData:
	var color: Color = Color.WHITE
	var value: int = -1
	var id: int = -1

	# roll_value: main.gd의 _roll_results[name]을 그대로 넘겨주세요.
	static func from_node(n: Node, roll_value: int = -999) -> DieData:
		var d := DieData.new()
		d.id = int(n.get_instance_id())

		# ---- color ----
		var col = n.get("dice_color") # main.gd에서 dice.dice_color로 설정됨
		if col == null:
			if n.has_meta("bag_key"):
				var key := str(n.get_meta("bag_key"))
				if BAG_COLOR_MAP.has(key):
					col = BAG_COLOR_MAP[key]
		if col == null:
			col = Color.WHITE
		d.color = col

		# ---- value ----
		if roll_value != -999:
			d.value = roll_value
		else:
			var v = n.get("die_value")
			if v == null:
				v = n.get("value")
			if v == null:
				v = n.get("last_result")
			if v == null:
				d.value = -1
			else:
				d.value = int(v)

		return d

# ===== 유틸/규칙 (동일) =====
static func _sorted_vals(dice: Array) -> Array:
	var vals: Array = []
	for d in dice: vals.append(int(d.value))
	vals.sort()
	return vals

static func _all_consecutive(vals: Array) -> bool:
	if vals.size() < 2: return false
	for i in range(1, vals.size()):
		if vals[i] != vals[i-1] + 1:
			return false
	return true

static func _all_same_num(dice: Array) -> bool:
	if dice.is_empty(): return false
	var v := int(dice[0].value)
	for d in dice:
		if int(d.value) != v: return false
	return true

static func _all_same_color(dice: Array) -> bool:
	if dice.is_empty(): return false
	var c: Color = dice[0].color
	for d in dice:
		if d.color != c: return false
	return true

static func _all_distinct_colors(dice: Array) -> bool:
	var s := {}
	for d in dice: s[d.color] = true
	return s.size() == dice.size()

static func _color_groups(dice: Array) -> Dictionary:
	var g := {}
	for d in dice:
		if not g.has(d.color): g[d.color] = []
		g[d.color].append(d)
	return g

static func is_run(dice: Array) -> bool:
	var vals := _sorted_vals(dice)
	for i in range(1, vals.size()):
		if vals[i] == vals[i-1]:
			return false
	return _all_consecutive(vals)

static func is_set(dice: Array) -> bool:
	return _all_same_num(dice)

static func is_color_fullhouse(dice: Array) -> bool:
	if dice.size() != 5: return false
	var cg := _color_groups(dice)
	if cg.size() != 2: return false
	var sizes: Array = []
	var values: Array = []
	for k in cg.keys():
		var arr: Array = cg[k]
		sizes.append(arr.size())
		if not _all_same_num(arr): return false
		values.append(int(arr[0].value))
	sizes.sort()
	if sizes.size() != 2 or sizes[0] != 2 or sizes[1] != 3: return false
	if FULLHOUSE_REQUIRE_DIFFERENT_VALUES and values[0] == values[1]: return false
	return true

class ComboResult:
	var ok: bool = false
	var combo_type: int = -1
	var size: int = 0
	var points: int = 0
	var reason: String = ""

static func eval_combo(dice: Array) -> ComboResult:
	var res := ComboResult.new()
	var n := int(dice.size())
	if n < 3 or n > 6:
		res.ok = false; res.reason = "허용 개수(3~6)가 아님"; return res

	if n == 5 and is_color_fullhouse(dice):
		res.ok = true
		res.combo_type = ComboType.COLOR_FULL_HOUSE
		res.size = 5
		res.points = SCORE_TABLE[res.combo_type][5]
		return res

	var run_ok := is_run(dice)
	var set_ok := is_set(dice)
	var all_same := _all_same_color(dice)
	var all_distinct := _all_distinct_colors(dice)

	if run_ok:
		if all_distinct and SCORE_TABLE[ComboType.RAINBOW_RUN].has(n):
			res.ok = true; res.combo_type = ComboType.RAINBOW_RUN
			res.size = n; res.points = SCORE_TABLE[res.combo_type][n]; return res
		if all_same and SCORE_TABLE[ComboType.SINGLE_COLOR_RUN].has(n):
			res.ok = true; res.combo_type = ComboType.SINGLE_COLOR_RUN
			res.size = n; res.points = SCORE_TABLE[res.combo_type][n]; return res

	if set_ok:
		if all_distinct and SCORE_TABLE[ComboType.RAINBOW_SET].has(n):
			res.ok = true; res.combo_type = ComboType.RAINBOW_SET
			res.size = n; res.points = SCORE_TABLE[res.combo_type][n]; return res
		if all_same and SCORE_TABLE[ComboType.SINGLE_COLOR_SET].has(n):
			res.ok = true; res.combo_type = ComboType.SINGLE_COLOR_SET
			res.size = n; res.points = SCORE_TABLE[res.combo_type][n]; return res

	res.ok = false
	res.reason = "정의된 조합이 아님"
	return res
