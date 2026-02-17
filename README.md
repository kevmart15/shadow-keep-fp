# Shadow Keep FP

A fast-paced first-person dungeon crawler with roguelike elements, procedurally generated dungeons, and a strategic card upgrade system.

## 🎮 Overview

Shadow Keep FP is a 3D action dungeon crawler built with Swift and SceneKit. Navigate through procedurally generated dungeons, battle enemies in real-time first-person combat, and upgrade your character through a roguelike card system. Each floor presents new challenges with increasing difficulty.

## ✨ Features

### Combat System
- **First-Person Melee Combat**: Real-time action with attack range and arc mechanics
- **Dash Ability**: Quick dodge with cooldown for tactical positioning
- **Knockback Mechanics**: Enemies are knocked back when hit
- **Attack Cooldowns**: Strategic timing-based combat (0.35s attack CD, 0.55s dash CD)

### Roguelike Card System
- **Weapon Cards**: Choose between different playstyles
  - Broadsword: +35% Damage, -15% Speed
  - Twin Daggers: +40% Attack Speed, -15% Damage
  - War Hammer: +50% Damage, Increased Knockback, -25% Speed

- **Upgrade Cards**: Permanent stat improvements
  - Iron Hide: +30 Max HP, Heal 30
  - Keen Edge: +20% Damage
  - Quick Hands: +25% Attack Speed
  - Fleet Foot: +20% Move Speed
  - Long Arms: +25% Attack Range

- **Buff Cards**: Temporary power-ups
  - Vampiric: +8% Lifesteal
  - Second Wind: Full Heal
  - Shield Orb: +40 Shield HP
  - Regeneration: +2 HP/sec

### Dungeon Generation
- **Procedural Generation**: Unique dungeons every playthrough
- **Progressive Difficulty**: Floor-based scaling (6-12 rooms per floor)
- **Room-Corridor System**: Connected rooms with widened corridors
- **Dynamic Layouts**: Varying room sizes (5x5 to 9x9 tiles)

### Visual Features
- **Atmospheric Fog**: Distance-based fog (starts at 15, ends at 35 units)
- **Dynamic Lighting**: Ambient and directional lighting
- **Color-Coded Systems**: Distinct colors for UI elements (Cyan, Red, Green, Gold, Purple, Orange)
- **Checkerboard Floor Pattern**: Visual variety in dungeon floors

### Progression System
- **XP and Leveling**: Defeat enemies to gain experience
- **Multiple Enemy Types**: 6+ enemy varieties with different XP values (15-60 XP)
- **Floor Progression**: Descend deeper into increasingly difficult floors

## 🕹️ Controls

- **Mouse**: Look around (camera control)
- **WASD**: Movement
- **Left Click**: Attack
- **Space/Shift**: Dash
- **Mouse Sensitivity**: 0.003 (X/Y)
- **Pitch Limit**: 1.3 radians (prevents camera over-rotation)

## 🎯 Game Mechanics

### Player Stats
- **Speed**: 9.0 units/sec
- **Attack Range**: 2.8 units
- **Attack Arc**: 126° (π * 0.7 radians)
- **Dash Speed**: 28.0 units/sec
- **Dash Duration**: 0.18 seconds

### Dungeon Specs
- **Grid Size**: 42x42 tiles
- **Tile Size**: 2.0 units
- **Wall Height**: 4.0 units
- **Camera Height**: 1.6 units (first-person eye level)

## 🛠️ Tech Stack

- **Language**: Swift
- **Graphics**: SceneKit (3D), SpriteKit (UI)
- **UI Framework**: AppKit
- **Math**: CoreGraphics
- **Platform**: macOS

## 🚀 Getting Started

### Prerequisites
- macOS 10.15 or later
- Xcode 13.0 or later
- Swift 5.5+

### Installation

1. Clone the repository:
```bash
git clone https://github.com/kevmart15/shadow-keep-fp.git
cd shadow-keep-fp
```

2. Compile the game:
```bash
swiftc main.swift -o shadow-keep-fp -framework AppKit -framework SceneKit -framework SpriteKit -framework CoreGraphics
```

3. Run the game:
```bash
./shadow-keep-fp
```

Alternatively, run the pre-built app:
```bash
open ShadowKeepFP.app
```

## 🎲 Gameplay Tips

1. **Choose Cards Wisely**: Your card selections define your build
2. **Use Dash Defensively**: Dodge enemy attacks and reposition
3. **Attack Arc Matters**: Position yourself to hit multiple enemies
4. **Watch Cooldowns**: Don't spam attacks, timing is crucial
5. **Explore Thoroughly**: Clear each floor before descending
6. **Balance Offense and Defense**: HP upgrades can be lifesavers

## 🏗️ Project Structure

- Procedural dungeon generation system
- Real-time 3D rendering with SceneKit
- Vector math extensions for smooth movement
- Card-based progression system
- Room connectivity algorithm
- Enemy spawn and behavior systems

## 📜 License

This project is open source and available under the MIT License.

## 👤 Author

**kevmart15**
- GitHub: [@kevmart15](https://github.com/kevmart15)

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

---

*Venture into the Shadow Keep. Only the strongest will survive.* ⚔️
