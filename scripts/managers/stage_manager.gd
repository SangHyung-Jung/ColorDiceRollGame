extends Node


# 다음 라운드로 진행할 때 발생하는 시그널
signal round_advanced(new_stage, new_round)
# 스테이지가 클리어되었을 때 발생하는 시그널
signal stage_cleared(stage)

# 스테이지 데이터 파일 경로
const STAGES_CSV_PATH = "res://stages.csv"

# 게임 상태 변수
var current_stage: int = 1
var current_round: int = 1

# 스테이지 데이터를 저장할 변수
# stages[stage_num][round_num] = target_score
var stage_data: Dictionary = {}

func _ready() -> void:
	_load_stage_data()
	# Main의 초기값을 StageManager의 값으로 설정
	Main.stage = current_stage
	Main.target_score = get_current_target_score()

## stages.csv 파일에서 스테이지/라운드 데이터를 로드합니다.
func _load_stage_data() -> void:
	var file = FileAccess.open(STAGES_CSV_PATH, FileAccess.READ)
	if not FileAccess.file_exists(STAGES_CSV_PATH):
		push_error("Stage data file not found at: " + STAGES_CSV_PATH)
		return

	# 첫 줄(헤더) 건너뛰기
	file.get_line()

	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 3:
			continue

		var stage_num = int(line[0])
		var round_num = int(line[1])
		var target = int(line[2])

		if not stage_data.has(stage_num):
			stage_data[stage_num] = {}
		
		stage_data[stage_num][round_num] = target

## 현재 라운드의 목표 점수를 반환합니다.
func get_current_target_score() -> int:
	if stage_data.has(current_stage) and stage_data[current_stage].has(current_round):
		return stage_data[current_stage][current_round]
	return 99999 # 데이터가 없는 경우, 비정상적으로 큰 수 반환

## 다음 라운드로 게임 상태를 전환합니다.
func advance_to_next_round() -> void:
	var next_round = current_round + 1
	if stage_data.has(current_stage) and stage_data[current_stage].has(next_round):
		# 다음 라운드로 진행
		current_round = next_round
		print("Advancing to Stage %d, Round %d" % [current_stage, current_round])
		
		# Main 상태 업데이트
		_update_main_state()
		round_advanced.emit(current_stage, current_round)
	else:
		# 현재 스테이지의 모든 라운드 클리어
		print("Stage %d Cleared!" % current_stage)
		stage_cleared.emit(current_stage)
		# 여기에 다음 스테이지로 넘어가는 로직을 추가할 수 있습니다.
		# 예: current_stage += 1; current_round = 1;

## Main 싱글톤의 상태를 현재 라운드에 맞게 업데이트합니다.
func _update_main_state() -> void:
	Main.stage = current_stage
	Main.target_score = get_current_target_score()
	Main.current_score = 0
	Main.turns_left = 4 # 턴/투자 횟수 등 초기화
	Main.invests_left = 5

## 라운드 클리어 상황을 처리합니다.
func handle_round_clear() -> void:
	print("Round %d Clear! Target: %d, Score: %d" % [current_round, get_current_target_score(), Main.current_score])
	# 팝업을 띄우는 로직은 main_screen.gd에서 처리하고
	# 팝업이 닫힐 때 이 클래스의 advance_to_next_round()를 호출하도록 연결합니다.
	pass

## 라운드 클리어 시 골드 보상을 계산합니다.
func calculate_round_rewards() -> Dictionary:
	var rewards = {
		"base": 0,
		"turns": 0,
		"interest": 0,
		"over_achieve": 0,
		"total": 0
	}
	
	# 1. 라운드 클리어 기본 보상: +$4
	rewards["base"] = 4
	
	# 2. 남은 턴 보너스: 1회당 +$1
	rewards["turns"] = Main.turns_left
	
	# 3. 이자 보너스: 보유 골드 $5당 +$1
	rewards["interest"] = int(floor(float(Main.gold) / 5.0))
	
	# 4. 초과 달성 보너스: 목표 점수의 150% 이상 달성 시 +$1
	if Main.current_score >= (get_current_target_score() * 1.5):
		rewards["over_achieve"] = 1
		
	# 총합 계산
	rewards["total"] = rewards["base"] + rewards["turns"] + rewards["interest"] + rewards["over_achieve"]
	
	# 계산된 골드를 실제 재화에 반영
	Main.gold += rewards["total"]
	
	return rewards
