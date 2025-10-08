## 입력 처리를 전담하는 매니저
## 마우스와 키보드 입력을 처리하여 게임 상태에 맞는
## 적절한 액션을 시그널로 전달합니다.
class_name InputManager
extends Node

# === 입력 이벤트 시그널들 ===
signal roll_started()  # 새 굴리기 시작 요청
signal combo_selection_toggled(active: bool)  # 조합 선택 모드 토글

# === 의존성 참조들 ===
var combo_select: ComboSelect  # 조합 선택 컴포넌트
var camera: Camera3D           # 레이캐스팅용 카메라

# === 입력 상태 플래그들 ===
var _roll_in_progress: bool = false   # 현재 굴리기 진행 중

## 입력 매니저 초기화
## @param combo_sel: 조합 선택 컴포넌트
## @param cam: 레이캐스팅에 사용할 카메라
func initialize(combo_sel: ComboSelect, cam: Camera3D) -> void:
	combo_select = combo_sel
	camera = cam

## 굴리기 진행 상태 설정
## @param in_progress: 굴리기 진행 중 여부
func set_roll_in_progress(in_progress: bool) -> void:
	_roll_in_progress = in_progress

## 입력 이벤트를 처리하고 소비 여부를 반환합니다
## @param event: 처리할 입력 이벤트
## @return 이벤트를 소비했으면 true
func handle_input(event: InputEvent) -> bool:
	# 조합 선택 컴포넌트가 이벤트를 처리했는지 확인
	if combo_select.process_input(event):
		return true  # 이벤트 소비됨

	# 마우스 좌클릭 처리 (새 롤 시작)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 굴리기 진행 중이 아니면 새 굴리기 시작
		if not _roll_in_progress:
			roll_started.emit()  # 굴리기 시작 시그널 발생
			return true

	return false  # 이벤트 미소비
