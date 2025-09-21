## 주사위 가방 관리 클래스
## 제한된 수량의 색상별 주사위를 관리하여 전략적 자원 관리를 제공합니다.
## 각 색상당 8개씩 총 40개의 주사위로 시작하며, 한 번 사용된 주사위는
## 가방에서 제거되어 게임에 전략적 요소를 추가합니다.
class_name DiceBag
extends RefCounted

# 사용 가능한 주사위 색상들 (White, Black, Red, Green, Blue)
const COLORS := ["W","K","R","G","B"]

# 각 색상별 남은 주사위 개수를 저장하는 딕셔너리
var _counts: Dictionary = {}   # 예: {"W":8,"K":8,"R":8,"G":8,"B":8}
var _total_left := 0  # 전체 남은 주사위 개수 (캐시)

## 가방을 풀 세트로 초기화합니다 (각 색상 8개씩)
func setup_full() -> void:
	_counts.clear()
	for c in COLORS:
		_counts[c] = 8  # 각 색상당 8개씩 설정
	_recalc_total()

## 가방에 남은 전체 주사위 개수를 반환합니다
func total_left() -> int:
	return _total_left

## 특정 색상의 남은 주사위 개수를 반환합니다
## @param color_key: 확인할 색상 키 ("W", "K", "R", "G", "B")
func count_of(color_key: String) -> int:
	return int(_counts.get(color_key, 0))

## 요청된 개수만큼 주사위를 뽑을 수 있는지 확인합니다
## @param n: 뽑고자 하는 주사위 개수
func can_draw(n: int) -> bool:
	return _total_left >= n

## 주사위를 한 개 뽑습니다
## @param color_hint: 우선적으로 뽑고 싶은 색상 (있을 경우)
## @return 뽑힌 주사위의 색상 키, 실패 시 빈 문자열
func draw_one(color_hint: String = "") -> String:
	if _total_left <= 0:
		return ""  # 가방이 비어있음

	var chosen := ""

	# 힌트 색상이 있고 그 색상이 남아있으면 우선 사용
	if color_hint != "" and count_of(color_hint) > 0:
		chosen = color_hint
	else:
		# 사용 가능한 색상들 중에서 랜덤 선택
		var avail: Array = []
		for c in COLORS:
			if _counts[c] > 0:
				avail.append(c)
		chosen = avail[randi() % avail.size()]

	# 선택된 색상의 개수 감소
	_counts[chosen] -= 1
	_recalc_total()
	return chosen

## 여러 개의 주사위를 뽑습니다
## @param n: 뽑을 주사위 개수
## @return 뽑힌 주사위들의 색상 키 배열
func draw_many(n: int) -> Array:
	var out: Array = []
	if n <= 0:
		return out

	# 요청 개수를 남은 개수로 제한
	n = min(n, _total_left)
	for i in n:
		out.append(draw_one())
	return out

## 잘못 뽑은 주사위들을 가방에 다시 넣습니다 (실행 취소용)
## @param colors: 다시 넣을 주사위들의 색상 키 배열
func undo_draw(colors: Array) -> void:
	for c in colors:
		if c is String and c in COLORS:
			_counts[c] += 1
	_recalc_total()

## 현재 가방 상태를 콘솔에 출력합니다 (디버깅용)
func debug_print() -> void:
	print(
		"[BAG] LEFT=", _total_left,
		"  W:", _counts["W"],
		"  K:", _counts["K"],
		"  R:", _counts["R"],
		"  G:", _counts["G"],
		"  B:", _counts["B"]
	)

## 전체 남은 주사위 개수를 다시 계산합니다 (내부 캐시 업데이트)
func _recalc_total() -> void:
	var t := 0
	for c in COLORS:
		t += int(_counts[c])
	_total_left = t
