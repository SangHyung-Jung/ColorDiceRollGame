# ColorComboDice2

A color-based dice combination game built with Godot 4, featuring physics-based dice rolling and strategic combo gameplay.

![Game Screenshot](screenshots/gameplay.png)

## 🎮 Game Overview

ColorComboDice2 is a strategic dice game where players roll colored dice to create specific combinations for points. The game features realistic physics simulation with a 3D dice cup and provides an engaging tactical experience.

### Key Features

- **Physics-based dice rolling** with realistic 3D simulation
- **Color combination system** with 5 different dice colors (White, Black, Red, Green, Blue)
- **Strategic gameplay** with dice selection and combo scoring
- **Modular architecture** for easy maintenance and extension

## 🎯 Gameplay

1. **Roll the dice** by clicking and holding the mouse to shake the cup
2. **Release** to pour dice onto the playing field
3. **Select combinations** using C key to toggle selection mode
4. **Score points** by creating valid color combinations
5. **Keep dice** for future rounds or use them immediately

### Combination Types

- **Rainbow Run**: Sequential values with different colors (e.g., 1-2-3-4-5, all different colors)
- **Rainbow Set**: Same values with different colors (e.g., 3-3-3-3, all different colors)
- **Single Color Run**: Sequential values with same color (e.g., 2-3-4-5, all red)
- **Single Color Set**: Same values with same color (e.g., 5-5-5, all blue)
- **Color Full House**: 3 of one color/value + 2 of another color/value

## 🏗️ Architecture

The project has been refactored from a monolithic 470-line main.gd into a clean, modular architecture:

### Project Structure

```
scripts/
├── main.gd                    # Main controller (171 lines)
├── core/                      # Core game logic
│   ├── game_manager.gd        # Game state management
│   ├── dice_bag.gd           # Dice inventory system
│   └── combo_rules.gd        # Combination rules & scoring
├── components/               # Game components
│   ├── cup.gd               # Physics-based cup
│   ├── dice_spawner.gd      # Dice creation & management
│   └── combo_select.gd      # Combination selection UI
├── managers/                # System managers
│   ├── input_manager.gd     # Input handling
│   ├── score_manager.gd     # Score tracking
│   └── scene_manager.gd     # Environment setup
└── utils/                   # Utilities
	├── constants.gd         # Game constants
	└── dice_picker.gd       # Mouse interaction
```

### Component Responsibilities

- **GameManager**: Handles game state, dice tracking, and round management
- **SceneManager**: Sets up 3D environment (camera, lighting, floor)
- **InputManager**: Processes mouse/keyboard input with signal-based communication
- **ScoreManager**: Evaluates combinations and tracks scoring
- **DiceSpawner**: Manages dice creation, physics, and positioning
- **Cup**: Provides realistic cup shaking and pouring animations

## 🛠️ Technical Details

### Architecture Benefits

- **Separation of Concerns**: Each component has a single, well-defined responsibility
- **Modularity**: Components can be modified independently
- **Signal-based Communication**: Loose coupling between systems
- **Constants Management**: All game values centralized in `GameConstants`
- **Type Safety**: Explicit type annotations throughout

### Key Systems

- **Physics Simulation**: Realistic dice rolling with Godot's physics engine
- **Color Bag System**: Finite dice pool with strategic resource management
- **Combo Evaluation**: Rule-based scoring with extensible combination types
- **Input Handling**: Responsive mouse/keyboard controls with state management

## 🚀 Getting Started

### Prerequisites

- Godot 4.4 or later
- Basic familiarity with Godot editor

### Installation

1. Clone the repository
2. Open the project in Godot
3. Run the main scene

### Controls

- **Left Click + Hold**: Shake the dice cup
- **Release**: Pour dice
- **C Key**: Toggle combination selection mode
- **Left Click (in selection mode)**: Select/deselect dice
- **Right Click (in selection mode)**: Confirm combination

## 🎨 Customization

The modular architecture makes customization straightforward:

- **Add new combination types**: Extend `ComboRules.gd`
- **Modify scoring**: Update `SCORE_TABLE` in `ComboRules.gd`
- **Change game constants**: Edit values in `GameConstants.gd`
- **Customize physics**: Modify parameters in cup and dice components

## 📋 Development Notes

### Recent Refactoring (2024)

- **Reduced main.gd from 470 to 171 lines** (64% reduction)
- **Extracted 7 specialized components** from monolithic structure
- **Implemented signal-based architecture** for better decoupling
- **Centralized constants** for easier tuning
- **Added explicit type annotations** for better code reliability

### Code Quality

- Clean separation between game logic, presentation, and input
- Comprehensive error handling and validation
- Consistent naming conventions and documentation
- Modular design supporting future extensions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the established architecture
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Godot Engine](https://godotengine.org/)
- Uses the dice-roller addon for 3D dice rendering
- Physics simulation powered by Godot's built-in physics engine
