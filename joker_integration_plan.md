# 조커 시스템 구현 마스터 플랜

## 1. 자산 및 데이터 조사 (Investigation)
- `Joker_List.xlsx`의 내용을 텍스트나 CSV 형식으로 확인하여 데이터 구조(컬럼)를 파악한다.
- `casino assets` 디렉토리를 찾아, 그 안에 있는 조커 이미지 파일들의 정확한 영문 파일명을 확인한다.
- 엑셀의 한글 이름과 이미지의 영문 파일명을 매칭하는 표를 작성하여 사용자에게 정확한지 확인받는다.

## 2. 통합 데이터 파일 생성 (Data Consolidation)
- 사용자가 확인해준 매칭 관계를 기반으로, 게임이 직접 읽어들일 `jokers.csv` 파일을 생성한다.
- `jokers.csv` 파일의 컬럼은 `id,korean_name,english_name,description,image_path` 와 같은 명확한 구조를 가진다. `image_path`는 `res://`로 시작하는 전체 경로를 포함한다.

## 3. 조커 관리자 구현 (JokerManager)
- `scripts/managers/joker_manager.gd` 경로에 새로운 GDScript 파일을 생성한다.
- 이 스크립트는 `jokers.csv` 파일을 게임 시작 시 읽어들여, 모든 조커 데이터를 딕셔너리 배열 등의 형태로 메모리에 저장한다.
- `get_all_jokers()`나 `get_joker_by_id(id)`와 같이, 게임의 다른 부분(상점 등)에서 조커 데이터를 쉽게 가져다 쓸 수 있는 함수들을 제공한다.
- `project.godot` 파일의 `[autoload]` 섹션에 `JokerManager`를 싱글톤으로 등록하여 전역적인 접근이 가능하게 한다.

## 4. 상점 시스템 분석 (Shop Analysis)
- `shop_screen.gd`와 `shop_screen.tscn` 파일의 내용을 읽고 분석한다.
- 상점에서 아이템(아마도 `Panel`이나 커스텀 씬)이 어떻게 동적으로 생성되고, `HBoxContainer`나 `GridContainer` 같은 컨테이너에 어떻게 추가되는지 코드 구조를 파악한다.
- 재사용 가능한 아이템 표시용 씬이 있는지 확인하고, 없다면 새로 만들지 기존 구조를 활용할지 결정한다.

## 5. 상점에 조커 아이템 추가 (Shop Integration)
- `shop_screen.gd`의 `_ready` 또는 별도의 `setup_shop_items` 함수를 수정한다.
- `JokerManager.get_all_jokers()`를 호출하여 모든 조커 데이터 목록을 가져온다.
- 목록의 각 조커에 대해 상점 아이템 UI를 하나씩 생성(instantiate)한다.
- 생성된 아이템 UI의 `TextureRect`에는 조커의 이미지를, `Label`에는 이름과 설명을 채워 넣는다.
- 완성된 아이템 UI를 상점 씬의 아이템 컨테이너 노드에 `add_child`로 추가한다.
