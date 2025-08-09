# Application Architecture

## Overview

This document outlines the architecture for a multi-threaded Odin-based graphics
application using SDL3 and WebGPU. The architecture prioritizes rapid
development iteration through hot reloading, clean separation of concerns, and
robust parallel processing.

### Core Design Principles

- **Thread Separation**: Clear isolation between application, game logic, rendering, and audio
- **Hot Reloading**: Support for both code and data reloading during development
- **Data-Driven Design**: Game behavior defined through external data files
- **Pure Functional Game Logic**: Game thread operates on immutable data structures
- **Asset Reference Model**: Game logic uses asset IDs, not raw asset data

## System Architecture

### Threading Model

The application uses a 3+N thread architecture:

1. **Main Thread**: SDL3 event handling, window management, WebGPU context, and rendering operations
2. **Game Thread**: Pure game logic simulation and state management
3. **Audio Thread**: Sound processing and SDL3 audio output
4. **Job System**: N job system threads for async operations

**WebGPU Threading Constraint**: WebGPU surfaces and resources cannot be safely accessed across threads. All WebGPU operations must occur on the thread that created the WebGPU context (Main Thread). This constraint led to consolidating rendering operations on the main thread rather than using a separate render thread.

#### Thread Communication Strategy

**Mixed Approach Based on Performance Requirements**:

- **Lock-free structures**: Only for high-frequency, latency-critical paths
  - Input Event Buffer: Lock-free circular buffer (Main → Game Thread)
  - Render Packet Buffer: Double-buffered structure (Game → Main Thread)
  - Audio Packet Buffer: Double-buffered structure (Game → Audio Thread)
  - Job Queue: Priority-based lock-free queue (Game → Job System)

- **Mutex-based solutions**: For low-frequency, reliability-focused communication
  - Job Result Queue: Mutex-protected queue (Job System → Game Thread)
  - Control Message System: Thread coordination and shutdown

- **Atomic operations**: For simple state flags and triggers
  - Data Reload Trigger: Atomic flag (Any Thread → Main Thread)
  - Code Reload Trigger: Atomic flag (Any Thread → Main Thread)

**Rationale**: Prioritize implementation simplicity over performance for
non-critical paths while maintaining thread independence to prevent cascade
delays. This approach balances development complexity with performance
requirements.

### Component Architecture

#### Application Layer

**Application Manager** (`src/app/app.odin`)
- SDL3 subsystem initialization and teardown
- Window lifecycle management
- WebGPU context creation and surface management
- Main event loop coordination

**Game API Interface** (`src/app/game_api.odin`)
- Dynamic library loading and management
- Game function pointer management
- Cross-platform shared library handling (.dll/.dylib/.so)
- Library versioning through UUID-based file copying

**Thread Coordinator**
- Thread lifecycle management (creation, monitoring, termination)
- Cross-thread communication setup
- Shutdown coordination across all threads
- Health monitoring and failure recovery

#### Input System

**Input Event Flow**: SDL3 Events --> Event Capture --> Thread-Safe Buffer --> Game Thread Consumer

**Components**:
- **Event Capture** (Main Thread): SDL3 event polling and processing
- **Input Buffer** (Shared): Lock-free circular buffer with frame labeling
- **Input Consumer** (Game Thread): Event processing and game state integration

**Input Buffer Sizing Strategy**:
- **Theoretical Maximum**: ~235 events per frame (all keys + mouse activity)
- **Buffer Size**: 512 events (power-of-2, ~2x safety margin)
- **Overflow Handling**: Drop newest events to preserve chronological order
- **Rationale**: Prevents lost inputs during temporary game thread slowdowns

**Event Processing Strategy**:
- **Buffering Approach**: Queue input packets for game thread processing
- **Benefits**: Preserves quick keypresses that occur between game frames
- **Overflow Behavior**: When buffer full, drop newest inputs to maintain input integrity
- **Event Coalescing**: SDL3 handles mouse motion coalescing automatically

#### Game Engine Core

**Game State Manager** (`src/game/game.odin`)
- Pure data container for all game state
- State versioning for hot reload compatibility
- Serialization/deserialization for game restarts
- Memory layout optimization for cache efficiency
- Exported interface functions: `game_state()`, `game_state_fingerprint()`

**Game Logic Processor** (`src/game/game.odin`)
- Dynamic library loading and management
- Function pointer swapping during hot reload
- Pure functional game update execution
- Timing measurement and performance monitoring
- Exported interface functions: `game_init()`, `game_deinit()`, `game_update()`

**Render Packet Generator**
- Game state --> render data translation
- Frustum culling and visibility determination
- Asset ID resolution (no raw asset data)
- Frame-consistent data packaging

**Data Loader**
- JSON data file hot reloading
- Data validation and integrity checking
- Configuration management (game vs application settings)
- Reload coordination with state management

#### Rendering System

**Main Thread Rendering Architecture**
- **WebGPU Operations**: All WebGPU rendering operations on Main Thread due to threading constraints
- **Render Packet Processing**: Process latest render packet from Game Thread during main loop
- **Frame Generation**: WebGPU command buffer creation and presentation integrated with event loop
- **GPU Resource Management**: Handle textures, buffers, shaders on Main Thread
- **Surface Operations**: Direct access to WebGPU surface without cross-thread complexity

**Render Packet Processing**
- **Latest Packet Consumption**: Main thread processes the most recent render packet during frame loop
- **Double Buffering**: Game thread writes to available buffer while Main thread reads from another
- **No Queueing**: Unlike input events, render packets are not queued - only the latest visual state matters
- **Buffer Management**: Game thread produces into available buffer, Main thread consumes latest completed buffer
- **Integrated Timing**: Rendering integrated with main thread event loop timing
- **Culling Data Interpretation**: Process visibility and rendering decisions from game thread
- **Asset ID → GPU Resource Resolution**: Convert game asset references to actual GPU resources
- **Command Buffer Generation**: Build WebGPU command sequences for frame rendering

**WebGPU Threading Architecture Benefits**
- **Single Thread Operations**: All WebGPU device, surface, and resource operations on Main Thread
- **No Cross-Thread Complexity**: Eliminates WebGPU validation errors and synchronization issues
- **Simplified Resource Management**: Direct access to resources without cross-thread coordination
- **Better Development Experience**: Cleaner debugging and fewer threading-related issues

**Shader Hot Reloading**:
- **Asset Treatment**: Shaders treated as resources identical to models, textures, and sounds
- **Background Loading**: Job system loads and compiles new shader resources asynchronously
- **Asset ID Consistency**: Game logic references shaders by ID, not direct resource handles
- **Resource Swapping**: Render system receives notification to switch to new shader resource and release old one
- **Unified Pipeline**: Same hot reload mechanism used for all asset types

**Design Questions**:
- GPU memory allocation patterns?

#### Audio System

**Audio Thread Components**
- **Audio Packet Consumer**: Processes latest audio packet from game thread, discarding older packets
- **Double Buffering**: Game thread writes audio events to available buffer while audio thread reads from another
- **No Queueing**: Like render packets, only the latest audio state matters - old sound events become irrelevant
- **Buffer Management**: Game thread produces audio events into available buffer, audio thread consumes latest completed buffer
- **Independent Timing**: Audio thread maintains consistent audio output regardless of game thread timing
- **Multi-Channel Mixing Engine**: Processes individual sound events and combines them into final audio output
- **SDL3 Audio Subsystem Interface**: Hardware audio device management and output streaming
- **Audio Resource Management**: Loading, caching, and lifecycle management of audio assets

**Audio Event Processing**
- Individual sound event handling (not pre-mixed streams)
- 3D audio positioning and attenuation
- Volume control and channel management
- Synchronization during hot reloads

#### Job System

**Worker Pool Management**
- Odin core:thread:Pool integration
- Simple integer-based priority system (higher = more urgent)
- **Job Timeout and Retry Configuration**:
  - **Timeout Config Types**:
    - **Fast Timeout**: Short timeout for quick operations (file reads, simple calculations)
    - **Standard Timeout**: Medium timeout for normal asset loading and processing
    - **Long Timeout**: Extended timeout for heavy operations (level loading, terrain generation)
    - **No Timeout**: Infinite timeout for operations that must complete (critical saves)
  - **Retry Config Types**:
    - **No Retries**: Fast fail for operations where failure indicates permanent issue
    - **Fixed Retries**: Limited retry count with immediate retry (N attempts total)
    - **Exponential Backoff**: Limited retries with increasing delay between attempts
    - **Infinite Retries**: Continuous retry with backoff for critical operations
    - **Progressive Timeout**: Retry with increasing timeout duration per attempt
  - **Configuration Examples**:
    - **Asset Loading**: Standard timeout + exponential backoff (temporary I/O issues)
    - **Game Save**: Long timeout + infinite retries (must not lose data)
    - **Shader Compilation**: Fast timeout + no retries (syntax errors don't resolve with retries)
    - **Network Operations**: Standard timeout + fixed retries (clear success/failure boundary)
- Worker health monitoring

**Job Categories**:
- Asset loading/unloading operations
- Level streaming and management
- Game save/load operations
- Long-running calculations (pathfinding, AI planning, terrain generation)

**Asset Loading Pipeline**:
1. **Game Request**: Game thread requests asset by ID (textures, models, shaders, sounds)
2. **Job Queue**: Asset loading job queued with appropriate priority
3. **Disk Loading**: Worker thread loads raw asset data from file system
4. **Format Processing**: Decode/process asset data (decompress textures, parse models, etc.)
5. **Resource Transfer**:
   - **GPU Assets**: Transfer to render thread for WebGPU resource creation
   - **Audio Assets**: Transfer to audio thread for SDL3 audio resource creation
   - **Data Assets**: Process and validate for game thread consumption
6. **Registry Update**: Update asset registry with loaded resource handles
7. **Completion Notification**: Notify game thread of successful loading via job result system
8. **Error Handling**: Failed loads logged and retry policies applied based on asset type

**Job Result Handling**
- **Pull-Based Event Log**: Job system maintains event log (created, started, completed, failed) that other threads query at controlled intervals
- **Game Thread Timing Control**: Game thread chooses when to check for job results during update phases, maintaining deterministic simulation
- **Pipeline Job Orchestration**: Complex job sequences handled internally by "pipeline jobs" that coordinate sub-jobs and return final results
- **Internal Job Coordination**: Pipeline jobs can wait on sub-jobs synchronously within the job system, no external callback chains needed
- **Simple Game Interface**: Game thread submits single pipeline job, receives single result - complexity hidden in job system
- **Result Data Marshaling**: Job results copied to game thread memory during controlled query operations
- **Error Handling and Recovery**: Failed jobs logged to event system, pipeline jobs handle sub-job failures internally
- **Resource Cleanup**: Failed jobs trigger cleanup procedures, pipeline jobs ensure proper resource management across sub-jobs

**Job Dependency Handling**:
- **No Formal Dependency System**: Pipeline jobs handle all dependency coordination internally
- **Sequential Dependencies**: Pipeline jobs wait for sub-jobs before proceeding to next step
- **Parallel Dependencies**: Pipeline jobs submit multiple sub-jobs and wait for completion
- **Conditional Logic**: Pipeline jobs can make decisions based on intermediate results
- **Simplicity Benefits**: Keeps job system as simple priority queue + workers, no complex dependency resolution

**Job Memory Allocation Strategy**:
- **Per-Job Growing Arena Allocators**: Each job receives its own growing arena allocator at creation
- **Growing Arena Design**: Allocator starts small and grows as needed, avoiding fixed size categories
- **Perfect Fit**: Large jobs (texture loading) can allocate gigabytes, small jobs (AI decisions) use kilobytes as needed
- **Automatic Cleanup**: Job completion or failure triggers cleanup of entire job allocator in single operation
- **Resource Transfer Protocol**: Successful jobs copy data from job allocator to permanent resource system storage
- **No Memory Categories**: Eliminates need to predict or hard-code job memory requirements
- **Leak Prevention**: Failed jobs automatically release all allocated memory without partial cleanup logic
- **Pipeline Job Isolation**: Each sub-job within pipeline gets own allocator for independent cleanup
- **Hot Reload Isolation**: Job allocators completely independent of game state - no special handling needed during hot reload

**Job Cancellation Mechanism**:
- **Simplified by Memory Strategy**: Per-job dynamic allocators eliminate complex partial cleanup logic
- **Cooperative Cancellation**: Jobs periodically check atomic cancellation flag during execution
- **Automatic Memory Cleanup**: Job exit (cancelled, failed, or completed) triggers entire job allocator cleanup
- **Worker Thread Coordination**: Cancellation flag checked at job boundaries and during long operations
- **Event Logging**: Cancelled jobs logged with "cancelled" status in job event system for game thread queries
- **Pipeline Cancellation**: Cancelling pipeline job sets cancellation flags for all sub-jobs, each cleans up independently
- **External Resource Cleanup**: Jobs responsible for cleaning up non-memory resources (files, connections) on cancellation detection

### Hot Reload Architecture

#### Reload Trigger System

**Trigger Types**:
- **Data Reload Trigger**: Thread-safe atomic flag for JSON data reloading
- **Code Reload Trigger**: Thread-safe atomic flag for game logic DLL reloading
- **Resource Reload Trigger**: Thread-safe atomic flag for asset reloading (textures, shaders, sounds, models)

**Activation Methods**:
- Hotkey bindings (configurable)
- File system watcher integration
- Manual trigger via development UI

#### Code Hot Reloading

**Shared Library Management**
- Async compilation via job system
- Dynamic loading with compatibility validation
- Function pointer swapping coordination
- Fail-safe behavior: Compilation or validation failure prevents reload, current code continues running

**Game State Handling**
- Compatibility detection for state struct changes
- Pre-reload serialization validation
- Game portion restart with state preservation
- Level save/restore cycle for seamless restarts

**Open Questions**:
- Cross-platform shared library naming?

#### Data Hot Reloading

**Data Pipeline**
- JSON file monitoring and parsing
- Data validation and integrity checking
- Atomic data structure replacement
- Feedback on reload success/failure

**Configuration Separation**
- **Application Settings**: Engine config stored in JSON format, not hot reloadable
- **Game Settings**: Gameplay data stored in JSON format, subject to hot reloading
- **Consistent Format**: Both use JSON for uniform parsing and human readability
- **Clear isolation**: Prevents engine state corruption during development

### Memory Architecture

#### Per-Thread Allocation Strategy

- **Main Thread**: Persistent allocators for SDL/WebGPU resources, temp allocators for events and rendering
- **Game Thread**: Frame-reset temp allocators, arena allocators for entities
- **Audio Thread**: Audio buffer pools, mixing calculation temp allocators
- **Job System**: Per-job allocators to prevent contention

#### Memory Sharing vs Copying

**Large Data (Render/Audio Packets)**: Copy between threads through buffers to avoid shared ownership
**Small State Data**: Atomic operations and immutable copies
**Asset References**: Share read-only IDs, copy mutable state

**Hot Reload Memory Management**:
- **Scope**: Memory pool recreation only applies to game state entity/component pools and render/audio packet buffers
- **Job System Isolation**: Per-job growing arena allocators unaffected by hot reload (jobs are transient with independent memory)
- **Pool Recreation**: Game Thread entity pools recreated when struct sizes change
- **Packet Buffers**: Render/Audio packet buffers resized if packet structures change
- **Transition Safety**: Temporary dual allocation during pool transitions for thread safety

**Fragmentation Mitigation**:
- **Generational Handles**: Entity and resource references use generational handles to detect stale references
- **Handle Maps with Free Lists**: Memory pools use handle-based allocation with free list reuse
- **Pool Memory Reuse**: Freed memory slots returned to free list for immediate reuse by new allocations
- **Defragmentation Strategy**: Handle indirection allows moving objects without breaking references

**Open Questions**:
- Memory pool sizing strategies?
- Custom allocator integration with Odin's memory management?
- Fragmentation mitigation approaches?

### Error Handling and Recovery

#### Thread Failure Recovery

**Core Thread Failure Strategy (Clean Exit)**:
- **Main Thread failure**: Immediate application shutdown with error logging (handles rendering + windowing)
- **Game Thread failure**: Save current state, display error message, exit application
- **Audio Thread failure**: Log audio error details, exit application gracefully
- **Rationale**: Core thread failures indicate fundamental system issues requiring user attention

**Job System Worker Failure Strategy (Graceful Recovery)**:
- **Worker Thread failure**: Catch exceptions, log failure details, restart worker thread
- **Job failure handling**: Apply retry policies (immediate, exponential backoff, or fail)
- **Work redistribution**: Redistribute failed job work to healthy job system threads
- **Graceful degradation**: Continue operation with reduced worker pool if needed

**Health Monitoring**:
- Per-thread health reporting to coordinator
- Failure detection through heartbeat system
- Safe shutdown coordination without data loss

#### Hot Reload Safety

- Shared library compatibility validation before loading
- Serialization compatibility checking before reload
- Reload cancellation for state preservation during validation failures
- **No Rollback Complexity**: Once validation passes, commit to new code (runtime crashes are development issues to fix)
- Clear error reporting with specific failure reasons for validation failures

#### Diagnostics and Logging

**Thread-Safe Logging**:
- Lock-free per-thread logging buffers
- Central log aggregation thread
- Thread identification in all messages
- Async I/O to prevent blocking

**Crash Handling**:
- Thread state capture with stack traces
- Hot reload state preservation for recovery
- Pre-crash game state serialization
- Diagnostic data for failed reload attempts

**Performance Monitoring System**:

**Per-Thread Performance Collectors**:
- **Main Thread**: SDL3 event processing time, window management overhead, WebGPU rendering time, GPU resource usage
- **Game Thread**: Simulation step timing, input processing duration, memory allocations
- **Audio Thread**: Audio mixing time, buffer underruns, SDL3 audio latency
- **Job System**: Worker utilization, job queue depths, completion rates

**Central Telemetry Aggregator** (Development Build Only):
- Collect metrics from all per-thread collectors via lock-free buffers
- Aggregate timing data, calculate averages and percentiles
- Detect performance anomalies and bottlenecks
- Export formatted data for external analysis tools

**Development UI Integration**:
- **Real-Time Metrics Display**: Live frame times, thread utilization, memory usage
- **Performance Graphs**: Historical performance data visualization
- **Bottleneck Detection**: Automatic identification of performance issues
- **Configurable Views**: Customizable metric displays for different debugging scenarios

**Metric Export Capabilities**:
- **JSON Export**: Human-readable performance data for analysis
- **CSV Export**: Time-series data for external graphing tools
- **Live Streaming**: Real-time metric streaming to external monitoring tools
- **Configurable Sampling**: Adjustable collection rates to minimize performance impact

### Development Tools Integration

#### Game State Recording/Replay

**Recording System**:
- Initial state capture
- Input sequence recording
- Deterministic replay capability
- Multiple recording slot management

**Integration Points**:
- Hot reload workflow integration
- State snapshot comparison
- Automated testing scenario creation

#### Snapshot System (Development Build Only)

**Capabilities**:
- On-demand complete game state capture
- JSON serialization for external inspection
- Multiple named snapshots for comparison
- Load snapshots as test starting states

**Development Workflow**:
- Before/after hot reload comparisons
- Debugging state analysis
- Regression testing data generation

**Build Exclusion**: Completely excluded from release builds through conditional compilation

## Data Design

### Game State Data Structures

**Core Data Organization**:
- **Game State Container**: Single root structure containing all game state
- **Entity Data**: Component-based entity storage with cache-friendly layouts
- **Configuration Data**: Hot-reloadable JSON data structures
- **Asset References**: ID-based asset referencing system

**Data Flow Patterns**:
- **Immutable Game State**: Pure functional updates with new state generation
- **Serialization Format**: JSON for human readability during development
- **Memory Layout**: Structure-of-arrays for performance-critical entity data
- **Versioning**: State structure versioning for hot reload compatibility

**Struct Versioning Strategy**:
- **Fingerprint Generation**: Hot reload component creates layout fingerprint during game state loading
- **Fingerprint Components**: Struct size + field count + field offsets + recursive type hash
- **Compatibility Check**: Simple fingerprint comparison (`old_fingerprint == new_fingerprint`)
- **Game Oblivious**: Game logic unaware of versioning, handled entirely by hot reload system
- **Layout Changes**: Any field reordering, addition, removal, or type change results in incompatible fingerprint

**Open Questions**:
- Entity-component storage optimization strategies?
- Asset dependency graph representation?
- Game state delta compression for large states?

### Inter-Thread Data Packets

**Render Packet Structure**:
- **Renderable Entities**: Post-culling entity rendering data
- **Asset References**: Texture, model, shader, and sound IDs
- **Camera State**: View and projection matrices
- **Lighting Data**: Light positions, colors, and parameters

**Audio Packet Structure**:
- **Sound Events**: Individual sound triggers with positioning
- **Audio State**: Volume levels, listener position and orientation
- **Asset References**: Sound file IDs and streaming parameters

**Input Packet Structure**:
- **Keyboard State**: Key press/release events with timing
- **Mouse State**: Position, button events, wheel data
- **Gamepad State**: Button and axis data for connected controllers

## Interface Design

### External Interfaces

**File System Interface**:
- **Data Directory**: JSON configuration and game data files
- **Asset Directory**: Textures, audio, models, and other game assets
- **Build System**: Integration with Odin build pipeline
- **Hot Reload**: File watching and dynamic loading capabilities

**Platform Interface (SDL3)**:
- **Window Management**: Creation, events, and lifecycle
- **Input Handling**: Keyboard, mouse, and gamepad events
- **Audio System**: Device management and audio output
- **WebGPU Context**: Graphics context creation and management

**Platform Abstraction Strategy**:
- **Application Layer**: SDL3 used directly throughout for window management, input, audio, and WebGPU context
- **Other Layers**: If game logic or other layers need platform services, access through abstraction layer
- **Rationale**: Minimizes unnecessary abstraction overhead while maintaining clean separation of concerns

### Internal Interfaces

**Thread Communication Interfaces**:
- **Lock-Free Buffers**: High-frequency data exchange protocols
- **Mutex-Protected Queues**: Low-frequency control messaging
- **Atomic Flags**: Simple state signaling between threads

**Hot Reload Interfaces**:
- **Shared Library Interface**: Dynamic loading and function resolution
- **Data Validation Interface**: JSON schema validation and integrity checking
- **State Serialization Interface**: Game state preservation protocols

**Job System Interface**:
- **Job Submission**: Priority-based task queuing for all async operations
- **Result Retrieval**: Completion notification and data marshaling via pull-based event log
- **Asset Loading Pipeline**: Complete 8-step pipeline from game request to resource availability
- **Resource Management**: Asset loading, processing, and cleanup coordination across threads

## Component Design

### Detailed Component Specifications

**[Component specifications already covered above in existing sections]**

**Component Interaction Patterns**:
- **Dependency Injection**: Components receive dependencies at initialization
- **Event-Driven Communication**: Components communicate via typed messages
- **Service Locator**: Centralized access to shared services and resources

**Component Lifecycle Management**:
- **Initialization Order**: Dependency-aware startup sequence
- **Shutdown Coordination**: Graceful termination with resource cleanup
- **Error Recovery**: Component restart and failure isolation

## User Interface Design

### Development Interface

**Hot Reload Controls**:
- **Hotkey Bindings**: Configurable key combinations for reload triggers
- **Visual Feedback**: On-screen indicators for reload status and errors
- **File Watcher Integration**: Automatic reload on file system changes

**Development vs Production Builds**:
- **Separate Entry Points**: Development and release builds use different main entry points and code files
- **Hot Reload Infrastructure**: Only included in development builds - hot reload managers, file watchers, and related systems
- **Clean Separation**: Release builds contain no hot reload logic, preventing accidental activation

**Debug Interface**:
- **Performance Metrics**: Integrated with Performance Monitoring System for real-time display of frame times, thread health, and bottleneck detection
- **State Inspector**: Runtime examination of game state structures
- **Memory Usage**: Per-thread allocation tracking and leak detection integrated with telemetry collectors

**Development Tools UI**:
- **Recording Controls**: Start/stop/replay game session recording
- **Snapshot Management**: Save/load/compare game state snapshots
- **Hotkey Bindings**: Configurable key combinations for all development tools and reload triggers

### Runtime Interface

**Application Window**:
- **Game Viewport**: Primary rendering surface for game content
- **Development Overlay**: Optional debug information display
- **Status Bar**: Basic application state and performance indicators

**Configuration Interface**:
- **Settings Files**: JSON format for both application and game configuration (consistent with data files)
- **Runtime Adjustment**: Limited runtime configuration changes
- **Profile Management**: Different configuration sets for development scenarios and release

## Assumptions and Dependencies

### Technical Assumptions

**Platform Assumptions**:
- **Desktop Target**: Windows, macOS, and Linux desktop systems
- **Hardware Requirements**: Dedicated GPU with WebGPU support
- **Memory Availability**: Sufficient RAM for multi-threaded operation
- **File System**: Standard file system access for hot reloading

**Development Environment**:
- **Odin Compiler**: Recent version with thread and dynamic library support
- **Build Tools**: Platform-appropriate compilation toolchain
- **Development Workflow**: File system watching capabilities

### External Dependencies

**Core Dependencies**:
- **SDL3**: Window management, input, audio, and WebGPU context
- **WebGPU**: Graphics API for cross-platform rendering
- **Odin Standard Library**: Threading, memory management, and I/O

**Optional Dependencies**:
- **File Watcher**: Platform-specific file system monitoring
- **JSON Parser**: Configuration and data file processing
- **Audio Codec Libraries**: Support for various audio formats

### Architectural Assumptions

**Performance Assumptions**:
- **Thread Scheduling**: OS provides reasonable thread scheduling
- **Memory Bandwidth**: Sufficient bandwidth for multi-threaded data copying
- **Storage Speed**: Fast enough storage for hot reload compilation

**Development Assumptions**:
- **Incremental Development**: Frequent code and data changes during development
- **Debugging Focus**: Development tools prioritized over production optimization
- **Learning Goals**: Architecture optimized for understanding parallel programming

## Glossary of Terms

**Arena Allocator**: Memory allocation strategy using contiguous memory blocks for efficient allocation and bulk deallocation

**Asset ID**: Unique identifier for game assets, avoiding direct asset data storage

**Audio Packet**: Data structure containing sound events and audio state

**Audio Thread**: Dedicated thread for sound processing and SDL3 audio output

**Circular Buffer**: Ring buffer data structure for efficient producer-consumer communication

**Culling**: Process of removing non-visible objects before rendering to optimize performance

**Development Tools**: Hot reload, recording/replay, and debugging utilities built into the application

**Double Buffering**: Technique using two buffers to avoid data races between producer and consumer

**Fingerprint**: Layout hash used for struct compatibility checking during hot reload operations

**Frame Labeling**: Tagging input events with frame numbers for proper game thread sequencing

**Game State**: Complete data representation of current game simulation state

**Game Thread**: Dedicated thread for pure functional game logic execution

**Generational Handle**: Reference system using generation counters to detect stale references after memory reuse

**Hot Reload**: Dynamic replacement of code or data without application restart

**Job System**: Thread pool for executing asynchronous operations

**Lock-Free**: Concurrent data structures that don't use mutex synchronization

**Main Thread**: Primary application thread handling SDL3 events, window management, and thread coordination

**Pipeline Job**: Job that coordinates multiple sub-jobs internally, presenting simple interface to game thread

**Pure Function**: Function with no side effects, given same input always produces same output

**Render Packet**: Data structure containing all information needed for frame rendering

**Main Thread Rendering**: WebGPU rendering operations integrated into main thread due to threading constraints

**SDL3**: Cross-platform library for window management, input, and audio

**Thread Coordinator**: Component responsible for managing thread lifecycle and communication

**Triple Buffering**: Extension of double buffering using three buffers to eliminate blocking between producer and consumer

**WebGPU Context**: Graphics API context for rendering operations

## Game Dynamic Library Interface

### Overview

The game logic is compiled as a dynamic library (.dll/.so/.dylib) to enable hot
reloading during development. The library exports a standardized interface that
the application uses to interact with game logic while maintaining complete
separation between engine and game code.

### Core Design Principles

**State Ownership**: Game library owns and manages all game state data structures
**Opaque State**: Application treats game state as opaque pointer - no knowledge of internal structure
**Pure Functions**: All exported functions are pure - no global state modification outside provided parameters
**Version Compatibility**: Interface includes version checking to prevent incompatible library loading
**Memory Management**: Game library responsible for its own memory allocation using provided allocators
**Asset References**: Game logic works with asset IDs only, never raw asset data

### Exported Function Interface

The game library exports a minimal, clean interface focused on essential functionality:

**`game_init()`**
- Called once after library loading to initialize game systems
- Game manages its own memory allocation and configuration loading
- No return value - initialization failure can be detected via other means

**`game_deinit()`**
- Called before library unloading to clean up game-specific resources
- Game releases all internally allocated memory and resources
- Ensures clean library unloading without memory leaks

**`game_update()`**
- Primary game simulation function called each frame by Game Thread
- Game manages input processing, state updates, and render/audio data internally
- All game logic, physics, AI, and simulation happens here

**`game_state() -> rawptr`**
- Returns opaque pointer to current game state
- Application uses this pointer for hot reload state preservation
- Game state structure is completely opaque to application

**`game_state_fingerprint() -> string`**
- Returns fingerprint/version string of current game state structure
- Used by hot reload system to detect incompatible state changes
- Changes when struct layout, field types, or sizes change
- Enables automatic detection of when game restart is required

### Interface Simplicity

The interface intentionally avoids exposing complex data structures:
- **No Parameter Passing**: Game functions take no parameters - the game manages input, configuration, and memory internally
- **Minimal State Exposure**: Only the opaque state pointer and fingerprint are exposed
- **Self-Contained**: Game library handles all complexity internally, presenting clean interface to application

### Function Pointer Management

#### Hot Reload Function Swapping
**Application Side**:
- Maintains function pointers to all exported game functions
- Atomically updates function pointers after successful library reload
- Falls back to stub functions if library loading fails
- Coordinates function swapping with Game Thread timing

**Game Library Side**:
- Exports functions with C calling convention for cross-platform compatibility
- Maintains internal state through provided allocators only
- Must handle being called during function pointer transition gracefully
- No assumptions about application-side function caching

### Error Handling and Safety

#### Library Loading Safety
- Version compatibility checked before any function calls
- Initialization failure prevents library usage
- Memory allocation failures handled gracefully with error returns
- State serialization failures prevent hot reload from proceeding

#### Runtime Error Handling
- All functions return status codes or null pointers on failure
- No exceptions or longjmp used (not compatible with C interface)
- Error conditions logged through application's logging system
- Failed operations leave game state in consistent state

#### Memory Safety
- Game library never retains pointers to application memory
- All inter-thread communication through copying, not shared pointers
- Asset references use IDs only, never direct pointers to application assets
- Allocator interfaces prevent game from accessing application memory pools

### Platform Considerations

#### Shared Library Naming
- **Windows**: `game_logic.dll`
- **macOS**: `game_logic.dylib`
- **Linux**: `game_logic.so`
- All platforms use same function export names for consistency

#### Calling Convention
- All exported functions use C calling convention (`extern "C"` equivalent)
- Simple parameter types (primitives, pointers, slices)
- No complex Odin-specific types in interface
- Cross-platform compatibility maintained through standardized interface

#### Symbol Export
- Explicit symbol export for all interface functions
- No internal game functions exported to prevent accidental usage
- Export definitions managed through build system configuration
- Development builds may export additional debugging functions

### Integration with Hot Reload System

#### Reload Trigger Response
1. **Compatibility Check**: New library version validated against current application
2. **State Serialization**: Current game state serialized for preservation
3. **Library Unload**: Old library shutdown and unloaded safely
4. **Library Load**: New library loaded and initialized
5. **State Restoration**: Serialized state deserialized into new library
6. **Function Update**: Application function pointers updated atomically
7. **Resume Operation**: Game Thread resumes with new library functions

#### Fallback Behavior
- **Compilation Failure**: Continue with current library, display error message
- **Loading Failure**: Rollback to previous working library if available
- **Initialization Failure**: Restart game portion with default initial state
- **State Incompatibility**: Restart game portion, losing current progress but preserving application

This interface design ensures clean separation between engine and game code while enabling robust hot reloading functionality essential for rapid development iteration.
