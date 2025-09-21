# ColorComboDice2: The Journey

A color-based dice combination game built with Godot 4, featuring physics-based dice rolling and a strategic journey through various opponents.

![Game Screenshot](screenshots/gameplay.png)
*(Note: Screenshot may not reflect the latest UI/Gameplay changes)*

## 🎮 Game Overview

ColorComboDice2: The Journey is a strategic dice game where players embark on an 8-stage journey, facing unique opponents in each stage. Players roll colored dice to create specific combinations for points, manage their hand and field dice, and strategically use limited submissions and investments to defeat opponents. The game features realistic physics simulation with a 3D dice cup and provides an engaging tactical experience.

### Key Features

- **Physics-based dice rolling** with realistic 3D simulation
- **Color combination system** with 5 different dice colors (White, Black, Red, Green, Blue)
- **Strategic gameplay** with Hand/Field dice management, combo scoring, and investment actions
- **'The Journey' System**: 8 unique stages with escalating target scores and challenging boss encounters
- **Modular and Extensible Architecture** for easy maintenance and addition of new features
- **Data-driven Boss Rules**: Boss abilities are loaded from JSON, allowing for flexible and diverse challenges

## 🎯 Gameplay: The Journey System

The game is structured around an 8-stage 'Journey'. Each stage involves defeating 3 opponents (2 normal, 1 boss) by reaching a target score within limited turns.

### Basic Flow

1.  **Challenge Start**: A target score is set. Players have limited **Submissions (제출)** and **Investments (투자)** per challenge (default: 4 Submissions, 5 Investments).
2.  **Turn Start**: 
    *   The 5 dice in your **Hand (패)** are automatically re-rolled.
    *   Dice in your **Field (필드)** remain as they are.
3.  **Player Action**: Choose one of two actions:
    *   **Submit Combo (조합 제출)**: Combine dice from your Hand and Field to score points. Used dice are removed, and your Hand is replenished.
    *   **Invest (투자)**: Move dice from your Hand to your Field for future turns. Your Hand is replenished.
4.  **Win/Loss**: Achieve the target score within the submission/investment limits to win. Failure results in a loss.
5.  **Rewards & Shop**: Winning a challenge grants **Funds ($)**, which can be used in the **Shop** to acquire powerful Joker items.
6.  **Progression**: Defeat all opponents in a stage to advance to the next. Defeating the final boss of Stage 8 wins the game.

### Scoring System

`Final Score = (Base Score Sum) × (Multiplier Sum) × Final Multiplier`

*   **Base Score**: Points from successful combos and Joker effects.
*   **Multiplier**: Sum of multipliers from Joker effects.
*   **Final Multiplier**: Product of all global multipliers from Joker effects.

### Combination Types

-   **Rainbow Run**: Sequential values with different colors (e.g., 1-2-3-4-5, all different colors)
-   **Rainbow Set**: Same values with different colors (e.g., 3-3-3-3, all different colors)
-   **Single Color Run**: Sequential values with same color (e.g., 2-3-4-5, all red)
-   **Single Color Set**: Same values with same color (e.g., 5-5-5, all blue)
-   **Color Full House**: 3 of one color/value + 2 of another color/value

## 🏗️ Architecture

The project has been refactored into a clean, modular, and data-driven architecture.

### Project Structure

```
scripts/
├── main.gd                    # 메인 오케스트레이터 및 진입점
├── core/                      # 핵심 게임 로직
│   ├── game_manager.gd        # 주사위 상태 관리(핸드, 필드 등)
│   ├── dice_bag.gd            # 주사위 인벤토리 시스템
│   └── combo_rules.gd         # 조합 규칙 및 점수 계산
├── components/                # 게임 구성 요소
│   ├── cup.gd                 # 물리 기반 컵
│   ├── dice_spawner.gd        # 주사위 생성, 관리 및 3D 위치 지정
│   └── combo_select.gd        # 조합 선택 UI 로직
├── managers/                  # 시스템 관리자
│   ├── input_manager.gd       # 입력 처리
│   ├── score_manager.gd       # 점수 추적
│   ├── scene_manager.gd       # 3D 환경 설정
│   ├── journey_manager.gd     # 게임 진행, 단계, 상대, 보스 규칙 관리
│   ├── joker_manager.gd       # 플레이어의 조커 아이템 및 효과 관리
│   └── data_manager.gd        # JSON 파일에서 게임 데이터 로드 및 제공
├── boss_rules/                # 보스 규칙의 특정 구현
│   ├── boss_rule.gd           # 모든 보스 규칙의 기본 클래스
│   ├── mom_rule.gd            # 엄마의 특정 규칙
│   ├── park_keeper_rule.gd    # 공원 관리인의 특정 규칙
│   ├── alley_boss_rule.gd     # 골목대장의 특정 규칙
│   ├── warehouse_owner_rule.gd# 창고 주인의 특정 규칙
│   ├── house_manager_rule.gd  # 하우스 매니저의 특정 규칙
│   ├── vip_host_rule.gd       # VIP 호스트의 특정 규칙
│   ├── casino_director_rule.gd# 카지노 지배인의 특정 규칙
│   └── final_boss_rule.gd     # 최종 보스의 특정 규칙
└── utils/                     # 유틸리티
    ├── constants.gd           # 게임 상수
    └── dice_picker.gd         # 3D 객체에 대한 마우스 상호 작용
```

### Component Responsibilities

-   **`Main`**: The central orchestrator. Initializes all managers, sets up the game, and connects signals between systems.
-   **`JourneyManager`**: Manages the overall game progression, including stages, opponents, target scores, player funds, and applying/removing boss rules.
-   **`GameManager`**: Handles the state of dice (in Hand, in Field, kept), manages dice results, and provides methods for dice manipulation (e.g., highlighting, fixing).
-   **`InputManager`**: Processes user input (mouse, keyboard) and translates it into game actions, emitting signals for dice selection, rolling, and mode changes.
-   **`ScoreManager`**: Evaluates dice combinations against `ComboRules` and tracks the player's score.
-   **`DiceSpawner`**: Responsible for creating, managing, and positioning 3D dice models in the game world, including visual updates.
-   **`JokerManager`**: Manages the player's acquired Joker items, their active/inactive states, and the application of their effects.
-   **`DataManager`**: A singleton that loads and provides game configuration data (boss rules, joker items) from external JSON files.
-   **`GameUI`**: The 2D user interface layer that displays game information (stage, score, funds, dice counts, boss rules) and provides interactive elements (buttons).
-   **`BossRule` (Base Class)**: Defines the interface for all specific boss rule implementations, allowing them to apply and remove their effects on the game state via `game_context`.
-   **`Dice` (Addon)**: The 3D dice model, extended to include visual feedback for fixed states and color changes.
-   **`GameConstants`**: A centralized script holding all game-wide constant values for easy tuning.

## 📊 Data Structure (JSON)

Game data for boss rules and joker items is managed via JSON files, allowing for easy external modification and expansion.

-   **`data/boss_rules.json`**: Defines each boss's unique rule, including its ID, name, description, and the `script_path` to its corresponding `BossRule` implementation.
-   **`data/joker_items.json`**: Defines various Joker items available in the shop, including their ID, name, description, price, and effect details.

## 😈 Implemented Boss Rules

All boss rules from the Game Design Document have been implemented using the generic `BossRule` system:

1.  **엄마 (Mom)**: "용돈 뺏기" - Reduces funds earned from combos.
2.  **공원 관리인 (Park Keeper)**: "자리 정리" - Randomly fixes one die in the Field each turn, making it unusable for that turn.
3.  **골목대장 (Alley Boss)**: "통행세" - Dice used in a combo are permanently removed from the game.
4.  **창고 주인 (Warehouse Owner)**: "보관료" - Loses 10% of funds when scoring a combo.
5.  **하우스 매니저 (House Manager)**: "하우스 규칙" - Disables the effect of the rightmost Joker.
6.  **VIP 호스트 (VIP Host)**: "패 뒤섞기" - Randomizes the colors of dice in the Hand at the start of each turn.
7.  **카지노 지배인 (Casino Director)**: "시간 압박" - Increases the target score by 5% at the end of each turn.
8.  **최후의 승부사 (The Final Boss)**: "마지막 승부" - Doubles the target score and makes all Joker effects 50% chance.

## 🚀 Getting Started

### Prerequisites

-   Godot 4.4 or later
-   Basic familiarity with Godot editor

### Installation

1.  Clone the repository.
2.  Open the project in Godot.
3.  Run the main scene (`project.godot` is configured to run the correct main scene).

### Controls

-   **Left Click + Hold**: Shake the dice cup
-   **Release**: Pour dice
-   **C Key**: Toggle combination selection mode
-   **Left Click (in combo selection mode)**: Select/deselect dice for combo
-   **Right Click (in combo selection mode)**: Confirm combination
-   **V Key**: Toggle invest selection mode
-   **Left Click (in invest selection mode)**: Select/deselect dice for investment
-   **Right Click (in invest selection mode)**: Confirm investment

## 🔮 Future Plans / TODOs

The game has a solid foundation, but there are several areas for future development:

1.  **Shop System Implementation**:
    *   Create a `ShopManager` and a dedicated UI for the shop.
    *   Allow players to spend funds to purchase Joker items from `joker_items.json`.
2.  **Joker Effects Implementation**:
    *   Fully implement the effects of all Joker items in `JokerManager`. This includes applying score multipliers, granting extra submissions/investments, etc.
    *   Ensure the 50% chance rule from "The Final Boss" is correctly applied to all Joker effects.
3.  **Game Over / Victory Screens**:
    *   Implement dedicated scenes for game over (loss) and victory (winning the final stage).
4.  **Sound and Music**:
    *   Add sound effects for dice rolls, button clicks, combo scoring, and background music to enhance immersion.
5.  **Visual Enhancements**:
    *   Improve UI design and aesthetics.
    *   Add more sophisticated dice animations and visual effects (e.g., for combo scoring, boss rule activations).
6.  **Testing and Debugging**:
    *   Thoroughly test all implemented features to ensure correct functionality and identify/fix bugs.
    *   Balance game mechanics (target scores, joker prices, fund rewards).

## 🤝 Contributing

1.  Fork the repository
2.  Create a feature branch
3.  Make your changes following the established architecture
4.  Test thoroughly
5.  Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

-   Built with [Godot Engine](https://godotengine.org/)
-   Uses the dice-roller addon for 3D dice rendering
-   Physics simulation powered by Godot's built-in physics engine