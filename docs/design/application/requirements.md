# Application Design

## Project Goals

- **Learning Focus**: Explore parallel programming and game engine architecture
- **Rapid Iteration**: Enable fast prototyping through hot reloading and tooling
- **Data-Driven Design**: All gameplay behavior defined in external data files
- **Strong Foundation**: Establish scalable architecture for future game development

## User Stories

### As a Game Developer (Primary User)

**Development Workflow Stories:**
- As a developer, I want to modify game logic without restarting the application so that I can iterate quickly on gameplay mechanics
- As a developer, I want to reload data files (stats, behaviors, config) without recompilation so that I can tweak values in real-time
- As a developer, I want to record and replay game sessions so that I can test specific scenarios repeatedly
- As a developer, I want to combine hot reloading with game looping so that I can rapidly prototype and tune gameplay values
- As a developer, I want responsive input handling even during heavy game processing so that debugging remains smooth

**Runtime Experience Stories:**
- As a developer, I want consistent frame rates regardless of game logic complexity so that visual feedback is reliable
- As a developer, I want audio to remain synchronized and glitch-free during hot reloads so that audio-dependent gameplay isn't disrupted
- As a developer, I want clear separation between application, game, and rendering concerns so that I can modify each independently

### As a Player (Secondary User - Future Consideration)

**Gameplay Experience Stories:**
- As a player, I want smooth, responsive gameplay with consistent performance
- As a player, I want synchronized audio that enhances the game experience
- As a player, I want the game to load and run reliably across different scenarios

## Core Requirements

### Threading Architecture Requirements

**Main Thread (Application/Window Management):**
- Handle SDL3 window events and system messages
- Create and manage OpenGL context through SDL3
- Populate thread-safe input event buffer for game thread consumption
- Manage application lifecycle and shutdown coordination
- Handle UI interactions (possibly shared with main thread)

**Game Thread (Simulation):**
- Execute game update logic at consistent intervals (pure functions on game state data)
- Consume input events from thread-safe buffer populated by main thread
- Generate render packets containing all visual state post-culling
- Generate audio packets containing sound events and mixing data post-culling
- Perform audio culling decisions based on full game state context
- Dispatch jobs to job system for async operations
- Support hot reloading of game logic code
- Support hot reloading of data files (stats, behaviors, config)
- Integrate with game looping/recording system

**Render Thread (Graphics):**
- Read most recent render packet from game thread buffer
- Perform all OpenGL operations and frame rendering
- Maintain consistent frame rate independent of game thread timing
- Handle OpenGL resource management (textures, buffers, shaders)

**Sound Thread (Audio):**
- Read most recent audio packet from game thread buffer
- Process audio events (start/stop/modify sounds)
- Handle audio mixing, volume control, and channel management
- Use SDL3 audio subsystem for hardware audio output
- Ensure audio remains synchronized during hot reloads
- Manage audio resource lifecycle

**Job System (Worker Threads):**
- Execute async operations dispatched from game thread with int-based priority system
- Handle asset loading/unloading operations
- Process level loading/unloading requests
- Execute game save/load operations
- Perform long-running calculations (terrain generation, pathfinding, AI planning)
- Built on Odin's core:thread:Pool for robust thread management
- Simple priority system: higher integer values = higher priority execution

### Hot Reloading Requirements

**Trigger-Based Hot Reloading:**
- Expose separate thread-safe triggers for data reload and code reload
- Support trigger activation via hotkey
- Support trigger activation via file watcher
- Decouple reload triggers from file monitoring for flexibility
- Coordinate reload operations across all affected threads

**Game Logic Hot Reloading:**
- Compile game update code as shared library when hot reload enabled (async job)
- Dynamically load new game logic during runtime
- Handle game state struct changes by restarting game portion (preserve application)
- Save level state before restart, auto-reload after game restart
- Fall back to compiled-in code when hot reload disabled
- Swap game update function after next game loop iteration completes

**Data Hot Reloading:**
- Read all JSON data from data directory (async job)
- Replace data structs after next game loop iteration completes
- Validate data integrity before applying changes
- Provide feedback on reload success/failure
- Load all game data (no selective reloading needed due to async execution)

**Game State Change Handling:**
- Detect incompatible game state struct changes during code reload
- Trigger game portion restart while keeping application running
- Preserve all serializable data within game state struct through restart cycle
- Automatically restore saved level after successful restart

### Development Tooling Requirements

**Game Looping System:**
- Record complete game state and input sequence
- Replay recorded sessions with identical behavior
- Integrate recording/replay with hot reloading workflow
- Support multiple recording slots for different scenarios

**Performance and Safety:**
- Thread-safe communication between all threads
- Graceful degradation when threads miss updates
- Consistent behavior regardless of timing variations
- Clear error handling and recovery mechanisms

## Technical Constraints

- Target platform: Desktop (initial), with consideration for future platforms
- Graphics API: OpenGL (context created through SDL3)
- Platform API: SDL3 for windowing, events, sound, and OpenGL context management
- Programming Language: Odin with data files in structured format (JSON)
- Performance: Maintain 60+ FPS during development workflow
- Dependencies: Keep external dependencies minimal and well-documented

## Design Philosophy

**Game Thread Asset Interaction:**
- Game thread operates on pure functions with game state data
- Game thread uses asset IDs/references, not raw asset data (textures, audio files, models)
- Specialized threads (Render, Audio, Job System) handle raw asset loading and management
- Exception: Collision shapes tied to entity types (logical game data, not raw assets)
- This separation maintains game logic purity and enables clean hot reloading

## Component Architecture

### Core Components

**Application Manager**
- **Purpose**: SDL3 initialization, window lifecycle, OpenGL context creation, main event loop
- **Components**:
  - SDL3 Subsystem Manager: Core platform initialization
  - Window Manager: Window creation and lifecycle
  - OpenGL Context Manager: Graphics context setup and management
- **Thread Affinity**: Main Thread
- **Interfaces With**: Input System, Hot Reload Manager, Thread Coordinator

**Thread Coordinator**
- **Purpose**: Thread lifecycle management, shutdown coordination, cross-thread communication setup
- **Components**:
  - Thread Lifecycle Manager: Creation, monitoring, and termination of threads
  - Communication Setup: Inter-thread data structure initialization
  - Shutdown Coordinator: Safe application termination across all threads
- **Thread Affinity**: Main Thread (coordinates others)
- **Interfaces With**: All other components

**Input System**
- **Purpose**: Event capture, input buffering, thread-safe event distribution
- **Components**:
  - Event Capture (Main Thread): SDL3 event polling and processing
  - Input Buffer (Shared): Thread-safe circular buffer for input events
  - Input Consumer (Game Thread): Event consumption and processing
- **Thread Affinity**: Main Thread → Game Thread communication
- **Key Features**: Lock-free circular buffer for high-performance input handling

**Game Engine Core**
- **Purpose**: Game logic execution, state management, render packet generation
- **Components**:
  - Game State Manager: Current world state, entity management
  - Game Logic Processor: Update loop execution (hot reloadable)
  - Render Packet Generator: Culling and render data preparation
  - Data Loader: Hot reloadable data file management
- **Thread Affinity**: Game Thread
- **Key Features**: Pure functional design, hot reloadable components

**Render System**
- **Purpose**: Graphics pipeline, frame generation, GPU resource management
- **Components**:
  - Render Packet Consumer: Reading latest render data from Game Thread
  - Graphics Pipeline: OpenGL operations and shader management
  - Frame Buffer Manager: OpenGL framebuffer operations and present operations
- **Thread Affinity**: Render Thread
- **Key Features**: Independent frame timing, OpenGL resource management

**Audio System**
- **Purpose**: Audio packet processing, sound mixing, audio resource management
- **Components**:
  - Audio Packet Consumer: Reading latest audio data from Game Thread
  - Audio Mixer: Sound event processing, volume control, channel management
  - Audio Resource Manager: Loading and caching audio assets
  - Audio Output Manager: SDL3 audio subsystem interface
- **Thread Affinity**: Sound Thread
- **Key Features**: Individual sound events with mixing instructions (not pre-mixed streams), asset ID-based interaction

**Job System**
- **Purpose**: Async operation execution, resource management, worker coordination
- **Components**:
  - Job Dispatcher: Queuing and prioritizing async operations (int-based priority)
  - Worker Pool: Odin core:thread:Pool-based thread management
  - Job Result Handler: Completion notification and result processing
- **Thread Affinity**: Multiple worker threads coordinated by Main Thread
- **Key Features**: Simple integer-based priority system (higher values = higher priority)

**Hot Reload Manager**
- **Purpose**: Dynamic library management, trigger-based reload coordination, game restart handling
- **Components**:
  - Library Loader: Dynamic library compilation and loading (async via job system)
  - Data Reload Trigger: Thread-safe trigger for data reload (Button A / hotkey)
  - Code Reload Trigger: Thread-safe trigger for game logic reload (Button B / hotkey)
  - Reload Coordinator: Safe reload execution across threads
  - Game Restart Manager: Game portion restart with full game state preservation
- **Thread Affinity**: Main Thread (coordinates reload across all threads)
- **Key Features**: Separate triggers for code vs data, game state preservation during restarts

**Development Tools**
- **Purpose**: Recording/replay, debugging aids, development UI
- **Components**:
  - Game State Recorder: Complete state and input capture
  - Replay System: Deterministic playback of recorded sessions
  - Debug Interface: Runtime inspection and manipulation tools
- **Thread Affinity**: Varies by component
- **Key Features**: Deterministic replay, hot reload integration

### Data Flow Architecture

**Input Flow:**
```
SDL3 Events → Input System (Main) → Input Buffer → Game Logic (Game Thread)
```

**Game Update Flow:**
```
Game Logic (Game Thread) → Game State → Render Packet Generator → Render Buffer
```

**Render Flow:**
```
Render Buffer → Render System (Render Thread) → OpenGL → Display
```

**Audio Flow:**
```
Game Logic (Game Thread) → Audio Packet Generator → Audio Buffer → Audio System (Sound Thread) → SDL3 Audio → Audio Hardware
```

**Job System Flow:**
```
Game Logic (Game Thread) → Job Dispatcher → Worker Pool → Job Results → Game Thread
```

**Hot Reload Flow:**
```
Reload Trigger → Hot Reload Manager (Main) → Thread Coordination → Dynamic Reload
```

### Inter-Thread Communication

**Thread-Safe Data Structures:**
- Input Event Buffer: Lock-free circular buffer (Main Thread → Game Thread)
- Render Packet Buffer: Double-buffered structure (Game Thread → Render Thread)
- Audio Packet Buffer: Double-buffered structure (Game Thread → Sound Thread)
- Job Queue: Priority-based lock-free queue (Game Thread → Job System)
- Job Result Queue: Lock-free queue (Job System → Game Thread)
- Control Message System: Thread coordination and shutdown
- Data Reload Trigger: Thread-safe trigger mechanism (Any Thread → Main Thread)
- Code Reload Trigger: Thread-safe trigger mechanism (Any Thread → Main Thread)

**Synchronization Strategy:**
- Minimize locking through lock-free data structures where possible
- Use atomic operations for simple state flags
- Employ message passing for complex coordination
- Maintain thread independence to prevent cascade delays

**Buffer Management:**
- Triple buffering for render packets to prevent blocking
- Double buffering for audio packets with mixing data preservation
- Circular buffers for input events to handle burst input
- Priority queues for Job System to handle urgent operations
- Memory pools to minimize allocation during hot paths
- Separate memory pools for Job System to prevent Game Thread allocation

### Error Handling and Recovery

**Thread Failure Recovery:**
- Each thread monitors its own health and reports to coordinator
- Graceful degradation: Continue operation with reduced functionality
- Safe shutdown: Coordinate thread termination without data loss

**Hot Reload Safety:**
- Validate shared library compatibility before loading
- Rollback capability if new code causes crashes
- State preservation during reload operations
- Game restart handling for incompatible state changes
- Level save/restore cycle for seamless game restarts
- Clear error reporting for reload failures

**Job System Error Recovery:**
- Handle worker thread failures without affecting Game Thread
- Job timeout handling and retry mechanisms
- Resource cleanup for failed async operations
- Graceful degradation when Job System becomes unavailable

**Resource Management:**
- OpenGL resource cleanup coordination between Game Thread and Render Thread
- SDL3 audio resource lifecycle management across reloads
- Job System resource cleanup for failed operations
- Memory leak prevention during dynamic library unloading
- Asset reference counting for safe unloading during jobs
