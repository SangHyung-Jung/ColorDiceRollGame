# res://dice_bag.gd
class_name DiceBag
extends RefCounted

const COLORS := ["W","K","R","G","B"]  # White, Black, Red, Green, Blue

var _counts: Dictionary = {}   # {"W":8,"K":8,"R":8,"G":8,"B":8}
var _total_left := 0

func setup_full() -> void:
	_counts.clear()
	for c in COLORS:
		_counts[c] = 8
	_recalc_total()

func total_left() -> int:
	return _total_left

func count_of(color_key: String) -> int:
	return int(_counts.get(color_key, 0))

func can_draw(n: int) -> bool:
	return _total_left >= n

## 한 개 뽑기: color_hint가 남아있으면 우선 사용
func draw_one(color_hint: String = "") -> String:
	if _total_left <= 0:
		return ""
	var chosen := ""
	if color_hint != "" and count_of(color_hint) > 0:
		chosen = color_hint
	else:
		var avail: Array = []
		for c in COLORS:
			if _counts[c] > 0:
				avail.append(c)
		chosen = avail[randi() % avail.size()]
	_counts[chosen] -= 1
	_recalc_total()
	return chosen

## n개 뽑기: 색상 키("W","K","R","G","B") 배열 반환
func draw_many(n: int) -> Array:
	var out: Array = []
	if n <= 0:
		return out
	n = min(n, _total_left)
	for i in n:
		out.append(draw_one())
	return out

## (옵션) 잘못 뽑은 것 복구
func undo_draw(colors: Array) -> void:
	for c in colors:
		if c is String and c in COLORS:
			_counts[c] += 1
	_recalc_total()

func debug_print() -> void:
	print(
		"[BAG] LEFT=", _total_left,
		"  W:", _counts["W"],
		"  K:", _counts["K"],
		"  R:", _counts["R"],
		"  G:", _counts["G"],
		"  B:", _counts["B"]
	)

func _recalc_total() -> void:
	var t := 0
	for c in COLORS:
		t += int(_counts[c])
	_total_left = t
