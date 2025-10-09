# Color Dice Roll Game

## 1. Project Overview

This is a dice rolling game where the player aims to achieve a high score by forming combinations of dice. The game is similar to Yahtzee but features colored dice and a unique scoring system. The project is built using the Godot Engine.

## 2. Game Rules

### Goal
The primary objective is to reach a target score within a limited number of turns.

### Game Flow
1.  **Initial State**: The game begins with 5 dice randomly drawn from a virtual bag and placed in the "invested" area. These dice are available for use in combinations from the start.
2.  **Turn Start**: A turn begins when the player rolls their hand of dice (the default hand size is 5). This is done by clicking the mouse on the rolling area.
3.  **Player Actions**: After the dice have been rolled and have settled, the player can perform the following actions within the same turn:
    *   **Submit a Combination**: The player can select a set of dice from their hand (the 3D dice in the rolling area) and/or the invested area (the 2D dice images) to form a valid combination. Multiple combinations can be submitted in a single turn.
    *   **Invest a Die**: The player can select a die from their hand and move it to the invested area. This action is limited by the number of investments remaining.
4.  **Turn End**: The player ends their turn by clicking the "Turn End" button.
5.  **Cleanup**: When a turn ends, any dice from the player's hand that were not used in a combination or invested are discarded from the game.
6.  **New Turn**: The `turns_left` counter is decremented. The player can then start a new turn by rolling a fresh hand of dice drawn from the bag.

### Scoring
*   The scoring system is defined by the combinations listed in `combo_definitions.csv`.
*   The score for a combination is calculated using the formula: `(Base Score + Sum of Dice Values) * Multiplier`.
*   Combinations have two types: "Multi-color" (`다색상`) and "Single-color" (`단일 색상`). Single-color combinations, which require all dice in the combo to be of the same color, yield significantly higher scores.

## 3. Project Structure

```
/
|-- main_screen.tscn       # Main game scene, contains the UI and 3D viewport.
|-- main_screen.gd         # Main script for the game, handles UI and game flow orchestration.
|-- project.godot          # The Godot project file.
|-- combo_definitions.csv  # CSV file defining the score, multiplier, and types for each combination.
|-- scripts/
|   |-- main.gd            # Global script (AutoLoad) for game state (turns, score, etc.).
|   |-- core/
|   |   |-- game_manager.gd  # Manages the core game state, roll tracking, and the dice bag.
|   |   |-- combo_rules.gd   # Defines all combination logic and the scoring system.
|   |   |-- dice_bag.gd      # Manages the pool of available dice to be drawn.
|   |-- managers/
|   |   |-- score_manager.gd # Evaluates selected dice against combo rules and updates the score.
|   |   |-- input_manager.gd # Handles player input for starting a roll and selecting dice.
|   |-- components/
|   |   |-- dice_spawner.gd  # Spawns, manages, and removes the 3D dice nodes.
|   |   |-- combo_select.gd  # Manages the selection of 3D dice in the rolling area.
|   |   |-- dice_face_image.gd # A custom Control node to display a 2D image of a single die face.
|-- addons/
|   |-- dice_roller/       # An addon providing the basic 3D dice models and rolling physics.
```

## 4. Core Scripts Explanation

*   **`main_screen.gd`**: This is the central script that connects all the different managers and components. It is responsible for updating the UI, handling button presses (`Submit`, `Invest`, `Turn End`), and driving the main game loop by calling the appropriate managers.

*   **`scripts/main.gd`**: A global singleton (configured via AutoLoad in Godot) that holds the persistent state of the game, such as `turns_left`, `current_score`, and `invests_left`.

*   **`game_manager.gd`**: Manages the state of a single roll, tracks the results of each die, and interfaces with the `DiceBag` to draw new dice.

*   **`score_manager.gd`**: This manager is responsible for scoring. It takes a set of selected dice (both 3D nodes and 2D UI nodes), passes them to `combo_rules.gd` for evaluation, and if a valid combination is found, it updates the global score.

*   **`combo_rules.gd`**: This is the heart of the game's scoring logic. It contains the `COMBO_DEFINITIONS` constant, which is a data structure holding all possible combinations, their conditions for validity (e.g., `is_full_house`, `is_straight`), base scores, and multipliers. The `eval_combo` function iterates through these definitions to find a matching combination for a given set of dice.

*   **`dice_spawner.gd`**: This component handles the entire lifecycle of the 3D dice nodes. It instantiates the dice scenes, applies physics for rolling, and removes them from the game.

*   **`combo_select.gd`**: Manages the selection of the 3D dice in the rolling area. It uses raycasting to detect clicks on dice and provides visual feedback for selected dice.

*   **`dice_face_image.gd`**: This is a custom `Control` node that displays a specific face of a die from a texture atlas. It is used to show the dice in the "invested" area. It also handles player input to allow these 2D images to be selected for combinations.