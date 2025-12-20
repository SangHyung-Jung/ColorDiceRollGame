## 점수 계산과 관리를 담당하는 매니저
## 선택된 주사위 조합을 평가하고 점수를 계산하며,
## 누적 점수를 추적합니다.
class_name ScoreManager
extends Node

# 유효한 조합이 완성되었을 때 발생
signal combo_scored_detailed(result: ComboRules.ComboResult, nodes: Array)

# 게임 전체의 누적 점수
var total_score: int = 0

## 선택된 주사위 조합을 평가하고 점수를 계산합니다
## @param selected_nodes: 선택된 주사위 노드들
## @param roll_results: 주사위별 결과값 딕셔너리
## @return 유효한 조합이면 true, 아니면 false
func evaluate_and_score_combo(selected_nodes: Array, roll_results: Dictionary) -> bool:
	# 입력 유효성 검사
	if selected_nodes.is_empty():
		print("조합이 없습니다(선택 안됨).")
		return false

	# 선택된 주사위들을 ComboRules에서 사용할 데이터로 변환
	var dice_data: Array = []
	var picked_labels: Array[String] = []  # 디버깅용 라벨

	for n in selected_nodes:
		# 주사위 결과값 추출
		var value: int = -1
		if typeof(roll_results) == TYPE_DICTIONARY and roll_results.has(n.name):
			value = int(roll_results[n.name])

		# ComboRules용 데이터 객체 생성
		var d := ComboRules.DieData.from_node(n, value)
		dice_data.append(d)

		# 디버깅용 라벨 생성
		var label := _get_color_label(n, d.color)
		picked_labels.append("%s-%d" % [label, d.value])

	print("[선택] ", picked_labels)

	# 조합 평가 실행
	var combo_rules = ComboRules.new()
	var result := combo_rules.eval_combo(dice_data)
	if not result.ok:
		print("조합이 없습니다.")
		return false

	# 성공: 점수 추가 및 결과 출력
	print("조합: %s | +%d점 (기본%d + 합%d) * 배율%d" % [
		result.combo_name, result.points, 
		result.base_score, result.dice_sum, result.multiplier
	])

	# [수정됨] 새로운 시그널 발생 (result 객체와 노드 전달)
	combo_scored_detailed.emit(result, selected_nodes)
	
	return true

## 주사위 노드에서 색상 라벨을 추출합니다
## @param node: 주사위 노드
## @param color: 주사위 색상
## @return 색상을 나타내는 문자열 ("W", "K", "R", "G", "B" 또는 HTML 색상 코드)
func _get_color_label(node: Node, color: Color) -> String:
	# 1순위: 주사위에 저장된 가방 키 사용
	if node.has_meta("bag_key"):
		return str(node.get_meta("bag_key"))

	# 2순위: 색상에서 직접 판단
	if color == Color.RED:
		return "R"
	if color == Color.GREEN:
		return "G"
	if color == Color.BLUE:
		return "B"
	if color == Color.WHITE:
		return "W"
	if color == Color.BLACK:
		return "K"

	# 3순위: HTML 색상 코드로 폴백
	return color.to_html(false)

## 현재 누적 점수를 반환합니다
func get_total_score() -> int:
	return total_score

## 점수를 초기화합니다 (새 게임 시작 등)
func reset_score() -> void:
	total_score = 0
