## 입력 처리를 전담하는 매니저
## 마우스와 키보드 입력을 처리하여 게임 상태에 맞는
## 적절한 액션을 시그널로 전달합니다.
class_name InputManager
extends Node

# === 입력 이벤트 시그널들 ===
signal roll_started()  # 새 굴리기 시작 요청
signal dice_selected(dice: Node3D)  # 주사위 선택 (보관용)
signal combo_selection_toggled(active: bool)  # 조합 선택 모드 토글
signal invest_selection_toggled(active: bool) # 투자 선택 모드 토글
signal dice_selected_for_invest(selected_dice: Array[Node3D]) # 투자할 주사위 선택 완료
signal dice_highlight_requested(dice: Node3D, highlight: bool) # 주사위 강조 요청

# === 의존성 참조들 ===
var combo_select: ComboSelect  # 조합 선택 컴포넌트
var camera: Camera3D           # 레이캐스팅용 카메라

# === 입력 상태 노기들 ===
var _selection_enabled: bool = false  # 주사위 선택 가능 여부
var _roll_in_progress: bool = false   # 현재 굴리기 진행 중
var _invest_selection_active: bool = false # 투자할 주사위 선택 모드 활성화 여부
var _selected_dice_for_invest: Array[Node3D] = [] # 투자할 주사위 임시 저장

## 입력 매니저 초기화
## @param combo_sel: 조합 선택 컴포넌트
## @param cam: 레이캐스팅에 사용할 카메라
func initialize(combo_sel: ComboSelect, cam: Camera3D) -> void:
	combo_select = combo_sel
	camera = cam

## 주사위 선택 가능 상태 설정
## @param enabled: 선택 가능 여부
func set_selection_enabled(enabled: bool) -> void:
	_selection_enabled = enabled

## 굴리기 진행 상태 설정
## @param in_progress: 굴리기 진행 중 여부
func set_roll_in_progress(in_progress: bool) -> void:
	_roll_in_progress = in_progress

## 입력 이벤트를 처리하고 소비 여부를 반환합니다
## @param event: 처리할 입력 이벤트
## @return 이벤트를 소비했으면 true
func handle_input(event: InputEvent) -> bool:
	# C키: 조합 선택 모드 토글
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_C:
			toggle_combo_selection()
			return true  # 이벤트 소비
	# V키: 투자 선택 모드 토글
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_V:
			toggle_invest_selection()
			return true  # 이벤트 소비

	# 조합 선택 컴포넌트가 이벤트를 처리했는지 확인
	if combo_select.process_input(event):
		return true  # 이벤트 소비됨

	# 마우스 좌클릭 처리
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_mouse_click(event)

	# 마우스 우클릭 처리 (투자 선택 확정)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _invest_selection_active:
			toggle_invest_selection() # Confirm selection
			return true

	return false  # 이벤트 미소비

## 조합 선택 모드를 토글합니다
## C키 누름 시 호출되며, 모드 변경을 시그널로 알립니다
func toggle_combo_selection() -> void:
	if combo_select.active:
		# 조합 선택 모드 비활성화
		combo_select.exit()
		print("조합선택 OFF")
		combo_selection_toggled.emit(false)
	else:
		# 조합 선택 모드 활성화
		combo_select.enter()
		print("조합선택 ON (좌클릭 선택/해제, 우클릭 확정)")
		combo_selection_toggled.emit(true)

func toggle_invest_selection() -> void:
	_invest_selection_active = not _invest_selection_active
	invest_selection_toggled.emit(_invest_selection_active)
	if not _invest_selection_active:
		# If deactivating, clear selection and emit
		for dice in _selected_dice_for_invest:
			dice_highlight_requested.emit(dice, false) # Unhighlight all selected dice
		if not _selected_dice_for_invest.is_empty():
			dice_selected_for_invest.emit(_selected_dice_for_invest)
			_selected_dice_for_invest.clear()
	else:
		_selected_dice_for_invest.clear()
		print("투자할 주사위 선택 ON (좌클릭 선택/해제, 우클릭 확정)")

## 마우스 클릭 이벤트를 처리합니다
## 게임 상태에 따라 주사위 선택 또는 굴리기 시작을 처리
func _handle_mouse_click(event: InputEventMouseButton) -> bool:
	if event.pressed:
		# 1. 투자 선택 모드일 때: 마우스 아래 주사위 선택/해제
		if _invest_selection_active:
			if _handle_invest_selection_click(event):
				return true

		# 2. 주사위 선택 모드일 때: 마우스 아래 주사위 찾기
		elif _selection_enabled: # Use elif to ensure only one mode is active
			if _handle_combo_selection_click(event):
				return true

		# 3. 새 굴리기 시작 (굴리기 진행 중이 아니면)
		elif not _roll_in_progress:
			roll_started.emit()  # 굴리기 시작 시그널 발생
			return true

	return false  # 이벤트 미소비

## 투자 선택 모드에서 마우스 클릭을 처리합니다
func _handle_invest_selection_click(event: InputEventMouseButton) -> bool:
	var hit_dice := DicePicker.pick_dice_under_mouse(camera, event.position, camera.get_world_3d())
	if hit_dice != null:
		if _selected_dice_for_invest.has(hit_dice):
			_selected_dice_for_invest.erase(hit_dice)
			dice_highlight_requested.emit(hit_dice, false) # Deselect and unhighlight
		else:
			_selected_dice_for_invest.append(hit_dice)
			dice_highlight_requested.emit(hit_dice, true) # Select and highlight
		return true
	return false

## 조합 선택 모드에서 마우스 클릭을 처리합니다
func _handle_combo_selection_click(event: InputEventMouseButton) -> bool:
	var hit_dice := DicePicker.pick_dice_under_mouse(camera, event.position, camera.get_world_3d())
	if hit_dice != null:
		dice_selected.emit(hit_dice)  # 주사위 선택 시그널 발생
		return true
	return false
