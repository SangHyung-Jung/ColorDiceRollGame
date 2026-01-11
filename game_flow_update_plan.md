# 라운드 사이 상점 방문 기능 구현 마스터 플랜

## 1. 메인 화면 수정 (main_screen)
- **UI 수정:** `main_screen.tscn`에서 'Shop' 버튼 노드를 완전히 제거한다.
- **스크립트 수정 (`main_screen.gd`):**
    - `@onready var shop_button` 변수와 `_on_shop_button_pressed` 함수, 그리고 관련 시그널 연결 코드를 모두 삭제한다.
    - `_on_round_clear_popup_continue_pressed` 함수의 내용을 `StageManager.advance_to_next_round()` 호출 대신 `get_tree().change_scene_to_file("res://shop_screen.tscn")`으로 변경한다.

## 2. 상점 화면 수정 (shop_screen)
- **UI 수정:** `shop_screen.tscn`의 'Back' 버튼의 `text`를 'Start Next Round'로 변경한다.
- **스크립트 수정 (`shop_screen.gd`):**
    - 기존 `_on_back_button_pressed` 함수의 이름을 `_on_next_round_button_pressed`로 변경하고, 버튼의 시그널 연결도 이에 맞게 수정한다.
    - `_on_next_round_button_pressed` 함수의 내용을 다음과 같이 변경한다:
        1. `StageManager.advance_to_next_round()`를 호출하여 게임 상태를 다음 라운드로 넘긴다.
        2. `get_tree().change_scene_to_file("res://main_screen.tscn")`을 호출하여 새 라운드가 설정된 메인 게임 화면으로 돌아간다.

## 3. 구매/판매 로직 기초 구현
- **구매 로직 (`joker_shop_item.gd`):**
    - `_on_buy_button_pressed` 함수 내에 구매 로직을 추가한다.
    - `joker_info` 딕셔너리에서 'Price'를 가져온다.
    - `if Main.gold >= price:` 조건을 확인한다.
    - 조건이 참이면, `Main.gold -= price`로 재화를 차감하고, `print()`로 구매 성공 메시지를 출력한다. 또한, 구매 후에는 버튼을 비활성화(`buy_button.disabled = true`)하여 중복 구매를 방지한다.
    - 조건이 거짓이면, `print()`로 골드 부족 메시지를 출력한다.
- **UI 업데이트:**
    - `shop_screen.gd`에서 아이템 구매/판매 후, 화면 상단에 표시되는 골드 UI가 업데이트되도록 로직을 추가한다. (예: `Main.gold`가 변경될 때마다 UI를 업데이트하는 전역 시그널 사용 또는 `shop_screen`에 진입할 때마다 UI 업데이트)
    - `main_screen.gd`의 좌측 골드 표시 UI가 항상 최신 상태를 반영하도록, `_ready` 함수와 `_process` 또는 노티피케이션을 통해 `Main.gold` 값을 지속적으로 확인하고 업데이트하는 로직을 보강한다.
