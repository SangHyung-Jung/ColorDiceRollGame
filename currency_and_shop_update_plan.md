# 화폐 및 보상 시스템 구현 마스터 플랜

## 1. 데이터 구조 확장
- `jokers.csv` 파일을 다시 읽어 `price`(가격)와 `grade`(등급) 컬럼의 존재와 형식을 확인한다.
- `JokerManager.gd`의 `_load_joker_data` 함수를 수정하여, `price`와 `grade`를 파싱하고 각 조커의 딕셔너리에 함께 저장하도록 한다. `price`는 정수형으로 변환한다.
- `scripts/main.gd`에 `var gold: int = 0` 변수를 추가하여 플레이어의 재화를 전역적으로 관리한다.

## 2. 보상 계산 로직 구현
- `StageManager.gd`에 `calculate_round_rewards() -> Dictionary` 함수를 새로 구현한다.
- 이 함수는 아래 규칙에 따라 보상을 계산한다:
    - **기본 보상:** +$4
    - **턴 보너스:** `Main.turns_left` * $1
    - **이자 보너스:** `floor(Main.gold / 5)` * $1
    - **초과 달성 보너스:** `Main.current_score >= Main.target_score * 1.5` 이면 +$1
- 함수는 각 항목별 보상과 총합(`"base": 4, "turns": 2, "total": 6` 등)을 담은 딕셔너리를 반환한다.
- 라운드 클리어 시 `StageManager`는 이 함수를 호출하여 계산된 총합을 `Main.gold`에 더한다.

## 3. UI 업데이트: 라운드 요약 창
- `round_clear_popup.tscn` 씬에 보상 내역 각 항목을 표시할 여러 개의 `Label` 노드를 추가한다. (예: `BaseRewardLabel`, `TurnsBonusLabel` 등)
- `round_clear_popup.gd`의 `setup` 함수가 기존 정보 외에 보상 딕셔너리도 인자로 받도록 수정한다.
- `setup` 함수는 전달받은 보상 딕셔너리의 값으로 새로 추가된 `Label`들의 `text`를 설정한다.
- `main_screen.gd`의 `_handle_round_clear` 함수에서 `StageManager.calculate_round_rewards()`를 호출하고, 그 결과를 팝업의 `setup` 함수에 전달하도록 수정한다.

## 4. UI 업데이트: 메인 화면 좌측 패널
- `main_screen.tscn`의 `InfoPanel` 내부 `VBoxContainer`에 `GoldLabel` 이라는 이름의 `Label` 노드를 추가한다.
- `main_screen.gd`에 `@onready var gold_label: Label` 변수를 추가한다.
- `main_screen.gd`에 `update_gold(amount: int)` 함수를 만들어 `gold_label.text`를 "Gold: $" + `str(amount)` 형식으로 설정하게 한다.
- `_update_ui_from_gamestate` 함수 내에서 `update_gold(Main.gold)`를 호출하여 UI가 항상 최신 재화 상태를 표시하도록 한다.

## 5. 조커 판매 기능 기반 마련
- `JokerManager.gd`에 `get_joker_sell_price(joker_id: int) -> int` 함수를 추가한다. 이 함수는 `ceil(price * 0.5)` 공식을 사용하여 올림 처리된 판매가를 계산한다.
- `shop_screen.tscn`에 "판매 모드" 진입/해제를 위한 `Button`을 추가한다.
- `shop_screen.gd`에 '판매 모드' 상태를 저장할 변수를 추가하고, 모드에 따라 `joker_shop_item`의 버튼 텍스트를 '구매' 또는 '판매'로 바꾸는 로직의 기반을 마련한다. (실제 판매 기능은 플레이어 인벤토리 시스템이 필요하므로 이번 단계에서는 UI 기반만 마련)
