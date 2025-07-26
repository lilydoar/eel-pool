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
- Create and manage WebGPU surface through SDL3
- Populate thread-safe input event buffer for game thread consumption
- Manage application lifecycle and shutdown coordination
- Handle UI interactions
- Coordinate between all threads (Game, Render, Audio, Job System)

**Render Thread (Graphics Operations):**
- Read most recent render packet from game thread buffer
- Perform all WebGPU operations and frame rendering
- Maintain consistent frame rate independent of game thread timing
- Handle WebGPU resource management (textures, buffers, shaders)
- Coordinate with Main Thread for WebGPU surface management

**Audio Thread (Sound Operations):**
- Read most recent audio packet from game thread buffer
- Process audio events (start/stop/modify sounds)
- Handle audio mixing, volume control, and channel management
- Use SDL3 audio subsystem for hardware audio output
- Ensure audio remains synchronized during hot reloads
- Manage audio resource lifecycle

**Game Thread (Simulation):**
- Execute game update logic at consistent intervals (pure functions on game state data)
- Consume input events from thread-safe buffer populated by main thread
- Generate render packets containing all visual state post-culling
- Generate audio packets containing sound events post-culling
- Perform audio culling decisions based on full game state context
- Dispatch jobs to job system for async operations
- Support hot reloading of game logic code
- Support hot reloading of data files (stats, behaviors, config)
- Integrate with game looping/recording system

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

**Configuration Management:**
- **Application Settings (Engine/Framework):**
  - Window configuration, graphics API settings, audio device selection
  - Hot reload trigger keys, development tool preferences
  - Thread configuration, memory pool sizes, performance settings
  - Stored in persistent application config files
  - Not subject to hot reloading (require application restart)
- **Game Settings (Content/Logic):**
  - Gameplay mechanics parameters, entity stats, balance values
  - Level configuration, game audio volumes, gameplay graphics settings
  - Stored in data directory with other game data files
  - Subject to hot reloading through data reload system
- **Settings Separation:**
  - Application settings isolated from game data to prevent hot reload interference
  - Game settings integrated with hot reloadable data pipeline
  - Clear distinction prevents accidental modification of engine state during development

**Game State Change Handling:**
- Detect incompatible game state struct changes during code reload
- Validate serialization compatibility before proceeding with hot reload
- Cancel hot reload if pre-reload serialization fails to preserve current scene
- Trigger game portion restart while keeping application running (only for successful serialization)
- Preserve all serializable data within game state struct through restart cycle
- Automatically restore saved level after successful restart
- Fallback to current state when deserialization fails after struct changes

### Development Tooling Requirements

**Game Looping System:**
- Record initial game state and input sequence
- Replay recorded sessions with identical behavior
- Integrate recording/replay with hot reloading workflow
- Support multiple recording slots for different scenarios

**Snapshot System:**
- Capture complete game state on-demand via hotkey or trigger
- Serialize captured state to JSON for inspection and analysis
- Support multiple named snapshots for comparison debugging
- Integrate with hot reloading workflow for before/after state comparison
- Export snapshots to external files for detailed analysis
- Load snapshots as starting states for testing scenarios

**Performance and Safety:**
- Thread-safe communication between all threads
- Graceful degradation when threads miss updates
- Consistent behavior regardless of timing variations
- Clear error handling and recovery mechanisms

## Build Configuration Requirements

### Development Build Features

**Development-Specific Components:**
- Hot reloading system for game logic and data files
- Game looping/recording system for rapid iteration
- Snapshot system for state capture and debugging
- Development UI and debugging tools
- Extended logging and diagnostic information
- File watcher integration for automatic reload triggers
- Memory leak detection and profiling tools
- Performance metrics collection and display

**Development Build Characteristics:**
- Larger binary size due to development tooling
- Higher memory usage for debugging structures
- Debug symbols and extended error information
- Relaxed performance constraints to accommodate tooling overhead
- Development-specific configuration file loading
- Detailed crash reporting and recovery mechanisms

### Release Build Features

**Release-Specific Optimizations:**
- Compiled game logic directly into executable (no dynamic loading)
- Minimal memory footprint through stripped debugging structures
- Optimized asset loading and memory management
- Production logging levels with essential information only
- Release-specific configuration validation

**Release Build Characteristics:**
- Smaller binary size with stripped development features
- Optimized performance without development overhead
- Essential error handling only (no development diagnostics)
- Production-ready resource management
- Minimal external dependencies
- Release configuration file validation

### Build System Requirements

**Conditional Compilation:**
- Separate build targets in build.odin script
- Use Odin build flags to separate development vs release features
- Compile-time feature toggles for development tooling inclusion
- Clear separation between dev-only and production code paths

**Configuration Management:**
- Development builds load from dev-specific config files
- Release builds use production configuration with validation
- Build-time configuration file generation for release
- Environment-specific build parameters

**Asset Pipeline Differences:**
- Development: Live asset loading and hot reloading support
- Release: Pre-processed and optimized asset bundles
- Development: Asset validation and detailed error reporting
- Release: Minimal asset validation for performance

## Technical Constraints

- Target platform: Desktop
- Graphics API: WebGPU (context created through SDL3)
- Platform API: SDL3 for windowing, events, sound, and WebGPU context management
- Programming Language: Odin with data files in structured format (JSON)
- Performance: Maintain 60+ FPS during development workflow, optimize for release
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
- **Purpose**: SDL3 initialization, window lifecycle, WebGPU context creation, main event loop
- **Components**:
  - SDL3 Subsystem Manager: Core platform initialization
  - Window Manager: Window creation and lifecycle
  - WebGPU Context Manager: Graphics context setup and management
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
- **Key Features**: Lock-free circular buffer for high-performance input handling, maintains event order from same source, events labeled with frame number for game thread queuing

**Game Engine Core**
- **Purpose**: Game logic execution, state management, render packet generation
- **Components**:
  - Game State Manager: Pure data container for game state memory, handles state versioning and serialization/deserialization for hot reload
  - Game Logic Processor: Loads and executes game DLL/shared library, manages function pointer swapping during hot reload, executes pure functional game updates with timing measurement
  - Render Packet Generator: Translates game state to render and audio packets, performs culling decisions, manages boundary between pure game logic and application services
  - Data Loader: Hot reloadable data file management, integrates with state versioning system
- **Thread Affinity**: Game Thread
- **Key Features**: Pure functional design, hot reloadable components, clear separation between data management and logic execution

**Render System**
- **Purpose**: Graphics pipeline, frame generation, GPU resource management
- **Components**:
  - Render Packet Consumer: Reading latest render data from Game Thread
  - Graphics Pipeline: WebGPU operations and shader management
  - Frame Buffer Manager: WebGPU framebuffer operations and present operations
- **Thread Affinity**: Main Thread
- **Key Features**: Independent frame timing, WebGPU resource management

**Audio System**
- **Purpose**: Audio packet processing, sound mixing, audio resource management
- **Components**:
  - Audio Packet Consumer: Reading latest audio data from Game Thread
  - Audio Mixer: Sound event processing, volume control, channel management
  - Audio Resource Manager: Loading and caching audio assets
  - Audio Output Manager: SDL3 audio subsystem interface
- **Thread Affinity**: Main Thread
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
- **Purpose**: Recording/replay, debugging aids, development UI, state inspection
- **Components**:
  - Game State Recorder: Complete state and input capture
  - Replay System: Deterministic playback of recorded sessions
  - Debug Interface: Runtime inspection and manipulation tools
  - Snapshot System: On-demand game state capture for debugging analysis
- **Thread Affinity**: Varies by component
- **Key Features**: Deterministic replay, hot reload integration, instant state capture

### Inter-Thread Communication

**Thread-Safe Data Structures:**
- Input Event Buffer: Lock-free circular buffer (Main Thread → Game Thread) - High frequency, latency-critical input handling with frame labeling
- Render Packet Buffer: Double-buffered structure (Game Thread → Render Thread) - Large data packets, frame-critical timing
- Audio Packet Buffer: Double-buffered structure (Game Thread → Audio Thread) - Large data packets, audio-critical timing
- Job Queue: Priority-based lock-free queue (Game Thread → Job System) - High throughput async operation dispatch
- Job Result Queue: Mutex-protected queue (Job System → Game Thread) - Lower frequency, batched result processing
- Control Message System: Mutex-protected messaging (Thread coordination and shutdown) - Low frequency, reliability over performance
- Data Reload Trigger: Atomic flag (Any Thread → Main Thread) - Simple boolean state, minimal complexity
- Code Reload Trigger: Atomic flag (Any Thread → Main Thread) - Simple boolean state, minimal complexity

**Synchronization Strategy:**
- Use lock-free structures only for high-frequency, latency-critical paths
- Use atomic operations for simple state flags and triggers
- Use mutex-based solutions for low-frequency, reliability-focused communication
- Employ message passing for complex coordination
- Maintain thread independence to prevent cascade delays
- Prioritize implementation simplicity over performance for non-critical paths
- Preserve event ordering from same source across thread boundaries

**Buffer Management:**
- Triple buffering for render packets to prevent blocking
- Double buffering for audio packets with event data preservation
- Circular buffers for input events to handle burst input
- Priority queues for Job System to handle urgent operations

**Memory Architecture:**
- **Per-Thread Allocation Strategies:**
  - Main Thread: Persistent allocators for window/SDL resources, temp allocators for event processing
  - Game Thread: Temp allocators reset every frame, arena allocators for entity/component data
  - Render Thread: Memory pools for GPU resources, temp allocators for per-frame render data
  - Audio Thread: Memory pools for audio buffers, temp allocators for mixing calculations
  - Job System: Separate arena allocators per worker to prevent contention
- **Memory Sharing vs Copying:**
  - Large packets (render/audio): Copy data between threads to avoid shared ownership
  - Small state data: Atomic operations and immutable copies
  - Asset references: Share read-only asset IDs, copy mutable state data
- **Lifetime Design:**
  - Frame-scoped data uses temp allocators reset each frame
  - Entity/component data uses backing arena allocators
  - Long-lived resources use dedicated memory pools
  - Minimize dynamic allocation through predictable lifetime patterns
- **Hot Reload Memory Management:**
  - Memory pool recreation when structure sizes change
  - Temporary dual allocation during pool transitions to maintain thread safety

### Error Handling and Recovery

**Thread Failure Recovery:**
- Each thread monitors its own health and reports to coordinator
- Graceful degradation: Continue operation with reduced functionality
- Safe shutdown: Coordinate thread termination without data loss

**Hot Reload Safety:**
- Validate shared library compatibility before loading
- Validate serialization compatibility before proceeding with reload
- Cancel reload operations that would lose current development state
- Rollback capability if new code causes crashes
- State preservation during reload operations
- Game restart handling for incompatible state changes
- Level save/restore cycle for seamless game restarts
- Clear error reporting for reload failures with specific failure reasons
- Memory pool reallocation when game state structures change size
- Safe cleanup of old memory pools before establishing new ones

**Job System Error Recovery:**
- Handle worker thread failures without affecting Game Thread
- Job timeout handling and retry mechanisms
- Resource cleanup for failed async operations
- Graceful degradation when Job System becomes unavailable

**Logging and Diagnostics:**
- **Thread-Safe Logging Infrastructure:**
  - Lock-free logging buffer per thread to prevent blocking
  - Central log aggregation on dedicated logging thread
  - Thread identification in all log messages for multi-threaded debugging
  - Async log writing to prevent I/O blocking on critical threads
- **Log Configuration:**
  - Configurable log levels per thread and subsystem
  - Runtime log level adjustment through application settings
  - Filtering by thread, component, or custom tags
  - Output routing (console, file, debug output) per log level
- **Crash Dump and Recovery:**
  - Thread state capture on crashes with stack traces
  - Hot reload state preservation for crash recovery
  - Game state serialization before potential crash operations
  - Diagnostic information for failed hot reload attempts

**Resource Management:**
- WebGPU resource cleanup coordination between Game Thread and Render Thread
- SDL3 audio resource lifecycle management across reloads
- Job System resource cleanup for failed operations
- Memory leak prevention during dynamic library unloading
- Asset reference counting for safe unloading during jobs
