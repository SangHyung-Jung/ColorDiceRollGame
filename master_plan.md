# 마스터 플랜: 스테이지 및 라운드 시스템 구현

## 1. 데이터 정의 (CSV)
- `stages.csv` 파일을 프로젝트 루트에 생성한다.
- 파일 형식은 `stage,round,target_score` 세 개의 컬럼으로 구성한다.
- 1 스테이지의 라운드별 목표 점수 (300, 600, 1200, 3000) 데이터를 입력한다.

## 2. 스테이지 관리자 (StageManager)
- `scripts/managers/stage_manager.gd` 경로에 새로운 GDScript 파일을 생성한다.
- 이 스크립트는 `Node`를 상속하며, `class_name StageManager`로 정의한다.
- `_ready` 함수에서 `stages.csv` 파일을 로드하여, 스테이지/라운드 데이터를 딕셔너리나 배열 형태로 저장한다.
- 현재 스테이지와 라운드를 추적하는 변수 (`current_stage`, `current_round`)를 선언한다.
- 외부에서 현재 목표 점수를 쉽게 가져올 수 있는 함수 `get_current_target_score()`를 구현한다.
- 다음 라운드로 진행하는 `advance_to_next_round()` 함수를 구현한다. 이 함수는 다음 라운드가 없으면 (예: 보스 라운드 클리어) 스테이지 클리어를 처리한다.
- `project.godot` 파일의 `[autoload]` 섹션에 `StageManager="*res://scripts/managers/stage_manager.gd"`를 추가하여 싱글톤으로 만든다.

## 3. 라운드 클리어 팝업 (RoundClearPopup)
- `scenes/popups/` 디렉토리를 생성한다.
- `scenes/popups/round_clear_popup.tscn` 이름으로 새로운 씬을 생성한다. `PanelContainer`나 `Window`를 루트 노드로 사용한다.
- 팝업에는 라운드 결과(예: "Round 1 Clear!", "Target: 300 / Result: 350")를 표시할 `Label`들과, 다음으로 진행하기 위한 `Button` ("Continue")을 배치한다.
- `scenes/popups/round_clear_popup.gd` 스크립트를 생성하여 팝업 씬에 연결한다.
- 이 스크립트는 `setup(round, target, result)` 같은 함수를 통해 팝업 내용을 동적으로 설정할 수 있어야 한다.
- "Continue" 버튼이 눌렸을 때, `stage_manager`에게 알리기 위한 시그널 `continue_pressed`를 정의한다.

## 4. 시스템 연동
- `main_screen.gd` 스크립트를 수정한다.
- `_animate_current_score` 함수의 tween이 완료되는 콜백 부분에서, `StageManager.get_current_target_score()`와 `Main.current_score`를 비교한다.
- 만약 `current_score`가 `target_score` 이상이면, `StageManager.handle_round_clear()` 같은 함수를 호출한다. (이 함수는 `StageManager`에 새로 구현)
- `StageManager`의 `handle_round_clear()` 함수는 `round_clear_popup` 씬을 인스턴스화하고, 필요한 정보를 `setup` 함수로 전달한 뒤, 화면에 표시하는 역할을 한다.
- `StageManager`는 `round_clear_popup`의 `continue_pressed` 시그널에 연결한다.
- 시그널을 받으면 `advance_to_next_round()`를 호출하여 게임 상태를 업데이트하고, `Main` 싱글톤의 `current_score`, `turns_left` 등을 초기화한다.
- `main_screen.gd`는 `_ready` 또는 `_process`에서 `StageManager`의 현재 상태를 지속적으로 UI에 반영하도록 수정한다. (예: `update_target_score(StageManager.get_current_target_score())`)
