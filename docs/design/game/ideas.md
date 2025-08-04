# Game

## Goal: I need to implement a simple game behavior that captures a general game's requirements.

- RTS (Real-Time Strategy)
- Platformer
- RPG, FPS, Racing, Puzzle games
- Any specific game genres or gameplay mechanics

Character fighting game
- player character has a weapon
- player character has a couple of moves
- player character is fun to move around in
- player character feels good to hit enemies with
- enemies have simple behavior patterns
- enemies are easily hit stun by player attacks
- difficulty is scaled by combination and number of enemies
- asset requirements
  - character art
  - character animations
  - 2-3 enemy designs
  - enemy animations
  - attack art
  - attack animations
  - character attack sounds
  - character hit sounds
  - character movement sounds
  - character injury sounds
  - enemy movement sounds
  - enemy attack sounds
  - enemy death sounds

Racing game
- player vehicle feels good to move around in
- player vehicle moves in a couple different ways (orthogonal design)
- opponent vehicles can complete a race
- opponent behavior can just be recordings of completed runs
- player and opponent do not need to interact directly for early prototype
- Track/course design and boundaries
- Lap counting and race completion detection
- Speed/acceleration mechanics
- Collision with track boundaries or obstacles
- Timer/race position tracking

RPG game
- character dialogue system
- npc state tracking for questlines/interaction
- battle system with simple turn-based mechanics
- battle system tile based movement
- map system with simple tile-based movement
- world state tracking for quests, events, and stories
- Inventory system for items/equipment
- Character stats/leveling system
- Save/load game state
- Item usage mechanics (potions, equipment)

RTS game
- Unit selection and control
- Unit pathfinding and movement
- Unit actions (attack, gather, build)
- Unit health and damage system
- Unit combat mechanics
- Unit spawning and management
- Opponent AI for resource gathering and combat
- Opponent base building and defense
- Map/level building
- Resource system (gathering, spending, storage)
- Building construction mechanics
- Tech tree or upgrade system
- Win/lose conditions
- Fog of war or vision system
- Economic balance (resource costs vs. benefits)
- one faction
  - a handful on unit types
  - fulfill different roles
  - design to be interesting when fighting against the same faction
    - a few different build paths maybe?

If I were to make a platformer game I would make a boss rush platformer combat game.
- perhaps combine the weapon combat of the character fighting game with platformer mechanics
- platforming is based around boss armour, shape, and movements
- character feels like a swinging monkey when moving(climbing?) around a boss

Core Game Systems:
- Health/damage system for both player and enemies
- Player death/respawn mechanics
- Score/progression system
- Level/stage progression or wave-based spawning
- Jump mechanics and gravity
- Platform collision detection
- Boss health/phase systems
- Grappling/climbing mechanics for the "swinging monkey" feel

User Interface:
- Health bar/UI elements
- Game over screen
- Pause menu
- Controls/input tutorial

Technical Requirements:
- Collision detection system
- Game state management (playing, paused, game over)
- Input handling/controls mapping
- Camera system (if needed)

Polish Elements:
- Screen shake/hit feedback effects
- Particle effects for attacks/deaths
- Background music/ambient sounds
- Environmental art/backgrounds

Gameplay Balance:
- Attack cooldowns/timing
- Movement speed tuning
- Enemy spawn rates/patterns
- Attack range and hitbox design

Cross-Game Considerations:
- Settings/options menu
- Audio volume controls
- Graphics/performance settings
- Key binding customization
