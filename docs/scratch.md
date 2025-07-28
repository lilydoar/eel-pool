
# Sun Jul 27 2025 - 1

Behavior trees

```odin
BehaviorNode :: struct {
    children: [dynamic]^BehaviorNode,
    execute: proc(node: ^BehaviorNode, context: ^BehaviorContext) -> BehaviorResult,
}

BehaviorResult :: enum {
    SUCCESS,
    FAILURE,
    RUNNING,
}

BehaviorContext :: struct {
    blackboard: map[string]any,
    delta_time: f32,
}
```

## What is a Blackboard?

The **blackboard** is a shared memory space that behavior tree nodes use to store and retrieve state information.
The name comes from the metaphor of a classroom blackboard where multiple participants (nodes) can write information for others to read.

**In this package specifically:** The blackboard serves as the primary communication mechanism between behavior tree nodes.
It contains all the runtime state needed for decision-making - sensor data, calculated values, flags, timers, and intermediate results.

**The Blackboard Pattern's Impact:**
- **Decoupling**: Nodes don't need direct references to each other; they communicate through shared data
- **Flexibility**: New behaviors can be added by simply reading/writing different blackboard keys
- **Debugging**: All decision-relevant state is centralized and inspectable
- **Persistence**: State naturally persists across behavior tree ticks without complex threading

**Example-specific meanings:**
- **Enemy AI**: Player position, noise locations, movement commands, pursuit state
- **Lever**: Physical position, health, interaction forces, event queues
- **Door**: Angle, velocity, collision data, environmental effects (dust, sound)
- **Swarm**: Individual observations, collective knowledge, role assignments, spatial data

The blackboard transforms behavior trees from simple decision trees into stateful,
reactive systems that can handle complex temporal behaviors and multi-agent coordination.

```odin
// Core composites
sequence :: proc(node: ^BehaviorNode, context: ^BehaviorContext) -> BehaviorResult
selector :: proc(node: ^BehaviorNode, context: ^BehaviorContext) -> BehaviorResult

// Essential decorator
inverter :: proc(child: ^BehaviorNode) -> ^BehaviorNode

// Leaf constructors
make_action :: proc(action: proc(^BehaviorContext) -> BehaviorResult) -> ^BehaviorNode
make_condition :: proc(condition: proc(^BehaviorContext) -> bool) -> ^BehaviorNode

// Convenient composite constructors (improvement based on usage patterns)
make_sequence :: proc(children: [dynamic]^BehaviorNode) -> ^BehaviorNode
make_selector :: proc(children: [dynamic]^BehaviorNode) -> ^BehaviorNode

// Blackboard query helpers (discovered need from examples)
bb_get :: proc(ctx: ^BehaviorContext, key: string, $T: typeid) -> (T, bool) {
    if key in ctx.blackboard {
        return ctx.blackboard[key].(T), true
    }
    return {}, false
}

bb_set :: proc(ctx: ^BehaviorContext, key: string, value: $T) {
    ctx.blackboard[key] = value
}

// Experimental: Generic behavior tree core
BehaviorContext_Generic :: struct($BlackboardType: typeid) {
    blackboard: BlackboardType,
    delta_time: f32,
}

BehaviorNode_Generic :: struct($BlackboardType: typeid) {
    children: [dynamic]^BehaviorNode_Generic(BlackboardType),
    execute: proc(node: ^BehaviorNode_Generic(BlackboardType), context: ^BehaviorContext_Generic(BlackboardType)) -> BehaviorResult,
}

// Generic composite constructors
make_sequence_generic :: proc($BlackboardType: typeid, children: [dynamic]^BehaviorNode_Generic(BlackboardType)) -> ^BehaviorNode_Generic(BlackboardType) {
    node := new(BehaviorNode_Generic(BlackboardType))
    node.children = children
    node.execute = proc(n: ^BehaviorNode_Generic(BlackboardType), ctx: ^BehaviorContext_Generic(BlackboardType)) -> BehaviorResult {
        for child in n.children {
            result := child.execute(child, ctx)
            if result != .SUCCESS do return result
        }
        return .SUCCESS
    }
    return node
}

make_selector_generic :: proc($BlackboardType: typeid, children: [dynamic]^BehaviorNode_Generic(BlackboardType)) -> ^BehaviorNode_Generic(BlackboardType) {
    node := new(BehaviorNode_Generic(BlackboardType))
    node.children = children
    node.execute = proc(n: ^BehaviorNode_Generic(BlackboardType), ctx: ^BehaviorContext_Generic(BlackboardType)) -> BehaviorResult {
        for child in n.children {
            result := child.execute(child, ctx)
            if result != .FAILURE do return result
        }
        return .FAILURE
    }
    return node
}

// Generic leaf constructors
make_action_generic :: proc($BlackboardType: typeid, action: proc(^BehaviorContext_Generic(BlackboardType)) -> BehaviorResult) -> ^BehaviorNode_Generic(BlackboardType) {
    node := new(BehaviorNode_Generic(BlackboardType))
    node.execute = proc(n: ^BehaviorNode_Generic(BlackboardType), ctx: ^BehaviorContext_Generic(BlackboardType)) -> BehaviorResult {
        return action(ctx)
    }
    return node
}

make_condition_generic :: proc($BlackboardType: typeid, condition: proc(^BehaviorContext_Generic(BlackboardType)) -> bool) -> ^BehaviorNode_Generic(BlackboardType) {
    node := new(BehaviorNode_Generic(BlackboardType))
    node.execute = proc(n: ^BehaviorNode_Generic(BlackboardType), ctx: ^BehaviorContext_Generic(BlackboardType)) -> BehaviorResult {
        return .SUCCESS if condition(ctx) else .FAILURE
    }
    return node
}

// Console debugging visualization
print_behavior_tree :: proc(node: ^BehaviorNode, depth: int = 0, is_last: bool = true, prefix: string = "") {
    if node == nil do return

    // Draw tree structure with Unicode box characters
    connector := "└── " if is_last else "├── "
    next_prefix := prefix + ("    " if is_last else "│   ")

    // Node type and status indicators
    node_type := get_node_type_name(node)
    status_icon := get_status_icon(node)

    fmt.printf("%s%s%s %s\n", prefix, connector, status_icon, node_type)

    // Print children
    child_count := len(node.children)
    for child, i in node.children {
        is_last_child := (i == child_count - 1)
        print_behavior_tree(child, depth + 1, is_last_child, next_prefix)
    }
}

get_status_icon :: proc(node: ^BehaviorNode) -> string {
    // Would need to track execution state, but for static representation:
    return "-"  // Idle: -, Running: >, Success: +, Failure: !
}

get_node_type_name :: proc(node: ^BehaviorNode) -> string {
    // Would need node type tracking, simplified for demo:
    if len(node.children) == 0 do return "Action/Condition"
    if len(node.children) > 0 do return "Composite"
    return "Unknown"
}

// Enhanced debug version with live state
print_behavior_tree_debug :: proc(node: ^BehaviorNode, ctx: ^BehaviorContext, depth: int = 0, is_last: bool = true, prefix: string = "") {
    if node == nil do return

    connector := "└── " if is_last else "├── "
    next_prefix := prefix + ("    " if is_last else "│   ")

    // Execute to get current status
    result := node.execute(node, ctx)
    status_icon := ""
    status_color := ""

    switch result {
    case .SUCCESS:
        status_icon = "+"
        status_color = "\033[32m"  // Green
    case .FAILURE:
        status_icon = "!"
        status_color = "\033[31m"  // Red
    case .RUNNING:
        status_icon = ">"
        status_color = "\033[33m"  // Yellow
    }

    node_name := get_node_debug_name(node, ctx)
    reset_color := "\033[0m"

    fmt.printf("%s%s%s%s %s%s\n", prefix, connector, status_color, status_icon, node_name, reset_color)

    child_count := len(node.children)
    for child, i in node.children {
        is_last_child := (i == child_count - 1)
        print_behavior_tree_debug(child, ctx, depth + 1, is_last_child, next_prefix)
    }
}

get_node_debug_name :: proc(node: ^BehaviorNode, ctx: ^BehaviorContext) -> string {
    // Would include relevant blackboard state for debugging
    if len(node.children) == 0 {
        return "Leaf Node" // Could show which action/condition
    }
    return fmt.tprintf("Composite (%d children)", len(node.children))
}

// Example output visualization:
/*
Enemy AI Behavior Tree:
└── > Root Selector
    ├── ! Chase Sequence
    │   ├── ! In Sight Cone (player_dist: 15.2m)
    │   └── - Chase Player
    ├── + Investigate Sequence
    │   ├── + Can Hear Player (noise_age: 2.1s)
    │   └── > Move To Noise (progress: 67%)
    └── - Wander In Circle

Blackboard State:
  enemy_pos: (12.4, 8.7)
  player_pos: (25.1, 12.3)
  last_noise_pos: (20.0, 10.0)
  time_since_noise: 2.1s
  move_direction: (0.8, 0.3)
*/
```

## Example 1: Searching Enemy AI

```odin
// Sight shape: fan with radius and angle constraints
in_sight_cone :: proc(ctx: ^BehaviorContext) -> bool {
    enemy_pos, _ := bb_get(ctx, "enemy_pos", Vec2)
    player_pos, _ := bb_get(ctx, "player_pos", Vec2)
    enemy_facing, _ := bb_get(ctx, "enemy_facing", Vec2)

    to_player := player_pos - enemy_pos
    distance := length(to_player)

    if distance > SIGHT_RADIUS do return false

    angle := dot(normalize(to_player), enemy_facing)
    return angle > cos(SIGHT_ANGLE / 2)
}

can_hear_player :: proc(ctx: ^BehaviorContext) -> bool {
    _, has_noise := bb_get(ctx, "last_noise_pos", Vec2)
    time_since, _ := bb_get(ctx, "time_since_noise", f32)
    return has_noise && time_since < NOISE_MEMORY_TIME
}

move_to_noise :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    enemy_pos, _ := bb_get(ctx, "enemy_pos", Vec2)
    noise_pos, _ := bb_get(ctx, "last_noise_pos", Vec2)

    if distance(enemy_pos, noise_pos) < ARRIVAL_THRESHOLD {
        delete_key(&ctx.blackboard, "last_noise_pos")
        return .SUCCESS
    }

    direction := normalize(noise_pos - enemy_pos)
    bb_set(ctx, "move_direction", direction)
    return .RUNNING
}

wander_in_circle :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    if !("wander_center" in ctx.blackboard) {
        ctx.blackboard["wander_center"] = ctx.blackboard["enemy_pos"]
        ctx.blackboard["wander_angle"] = rand.float32() * TAU
    }

    wander_angle := ctx.blackboard["wander_angle"].(f32)
    wander_center := ctx.blackboard["wander_center"].(Vec2)

    ctx.blackboard["wander_angle"] = wander_angle + WANDER_SPEED * ctx.delta_time

    target := wander_center + Vec2{cos(wander_angle), sin(wander_angle)} * WANDER_RADIUS
    direction := normalize(target - ctx.blackboard["enemy_pos"].(Vec2))
    ctx.blackboard["move_direction"] = direction

    return .RUNNING
}

chase_player :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    enemy_pos := ctx.blackboard["enemy_pos"].(Vec2)
    player_pos := ctx.blackboard["player_pos"].(Vec2)

    direction := normalize(player_pos - enemy_pos)
    ctx.blackboard["move_direction"] = direction
    ctx.blackboard["last_noise_pos"] = player_pos  // Update noise memory
    ctx.blackboard["time_since_noise"] = 0.0

    return .RUNNING
}

// Build the AI tree
enemy_ai := make_selector([dynamic]^BehaviorNode{
    make_sequence([dynamic]^BehaviorNode{
        make_condition(in_sight_cone),
        make_action(chase_player),
    }),
    make_sequence([dynamic]^BehaviorNode{
        make_condition(can_hear_player),
        make_action(move_to_noise),
    }),
    make_action(wander_in_circle),
})
```

## Example 2: In-Scene Lever

```odin
LeverEvent :: enum {
    LEVER_PULLED,
    LEVER_RELEASED,
    LEVER_BROKEN,
    LEVER_JAMMED,
}

emit_event :: proc(ctx: ^BehaviorContext, event: LeverEvent) {
    if !("event_queue" in ctx.blackboard) {
        ctx.blackboard["event_queue"] = make([dynamic]LeverEvent)
    }
    queue := &ctx.blackboard["event_queue"].([dynamic]LeverEvent)
    append(queue, event)
}

is_being_interacted :: proc(ctx: ^BehaviorContext) -> bool {
    return "interaction_force" in ctx.blackboard &&
           ctx.blackboard["interaction_force"].(f32) > INTERACTION_THRESHOLD
}

is_lever_broken :: proc(ctx: ^BehaviorContext) -> bool {
    return ctx.blackboard["lever_health"].(f32) <= 0
}

is_lever_jammed :: proc(ctx: ^BehaviorContext) -> bool {
    return "jam_timer" in ctx.blackboard &&
           ctx.blackboard["jam_timer"].(f32) > 0
}

// Boolean interface convenience functions for data file mapping
lever_is_pulled :: proc(ctx: ^BehaviorContext) -> bool {
    position, exists := bb_get(ctx, "lever_position", f32)
    return exists && position >= PULL_THRESHOLD
}

lever_is_at_rest :: proc(ctx: ^BehaviorContext) -> bool {
    position, exists := bb_get(ctx, "lever_position", f32)
    return exists && position <= 0.1
}

lever_is_functional :: proc(ctx: ^BehaviorContext) -> bool {
    health, exists := bb_get(ctx, "lever_health", f32)
    return exists && health > 0 && !is_lever_jammed(ctx)
}

lever_can_be_activated :: proc(ctx: ^BehaviorContext) -> bool {
    return lever_is_functional(ctx) && !lever_is_pulled(ctx)
}

lever_position_normalized :: proc(ctx: ^BehaviorContext) -> f32 {
    position, exists := bb_get(ctx, "lever_position", f32)
    if !exists do return 0.0
    return position
}

handle_pull :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    force := ctx.blackboard["interaction_force"].(f32)
    position := ctx.blackboard["lever_position"].(f32) // 0.0 to 1.0

    // Apply force based interaction
    new_position := clamp(position + force * LEVER_SENSITIVITY * ctx.delta_time, 0, 1)
    ctx.blackboard["lever_position"] = new_position

    // Check if fully pulled
    if position < PULL_THRESHOLD && new_position >= PULL_THRESHOLD {
        emit_event(ctx, .LEVER_PULLED)
    } else if position >= PULL_THRESHOLD && new_position < PULL_THRESHOLD {
        emit_event(ctx, .LEVER_RELEASED)
    }

    // Damage from excessive force
    if force > DAMAGE_THRESHOLD {
        health := ctx.blackboard["lever_health"].(f32)
        ctx.blackboard["lever_health"] = health - DAMAGE_RATE * ctx.delta_time

        if health <= 0 {
            emit_event(ctx, .LEVER_BROKEN)
        }
    }

    return .RUNNING
}

apply_spring_return :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    position := ctx.blackboard["lever_position"].(f32)

    // Spring back toward rest position (0.0)
    spring_force := -position * SPRING_CONSTANT
    new_position := clamp(position + spring_force * ctx.delta_time, 0, 1)
    ctx.blackboard["lever_position"] = new_position

    return .RUNNING
}

handle_jam :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    jam_timer := ctx.blackboard["jam_timer"].(f32)
    ctx.blackboard["jam_timer"] = jam_timer - ctx.delta_time

    if jam_timer <= 0 {
        delete_key(&ctx.blackboard, "jam_timer")
        return .SUCCESS
    }

    emit_event(ctx, .LEVER_JAMMED)
    return .RUNNING
}

break_permanently :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    ctx.blackboard["lever_position"] = rand.float32() * 0.3 // Broken position
    emit_event(ctx, .LEVER_BROKEN)
    return .RUNNING
}

// Build lever behavior tree
lever_tree := make_selector([dynamic]^BehaviorNode{
    make_sequence([dynamic]^BehaviorNode{
        make_condition(is_lever_broken),
        make_action(break_permanently),
    }),
    make_sequence([dynamic]^BehaviorNode{
        make_condition(is_lever_jammed),
        make_action(handle_jam),
    }),
    make_sequence([dynamic]^BehaviorNode{
        make_condition(is_being_interacted),
        make_action(handle_pull),
    }),
    make_action(apply_spring_return),
})
```

## Example 3: In-Scene Door (Physical Simulation via Behavior Tree)

```odin
DoorState :: enum {
    CLOSED,
    OPENING,
    OPEN,
    CLOSING,
    BROKEN,
    ABSENT,
}

// Door physical queries - the behavior tree IS the physical simulation engine
is_door_fully_closed :: proc(ctx: ^BehaviorContext) -> bool {
    return ctx.blackboard["door_angle"].(f32) <= 0.01
}

is_door_partway_open :: proc(ctx: ^BehaviorContext) -> bool {
    angle := ctx.blackboard["door_angle"].(f32)
    return angle > 0.01 && angle < ctx.blackboard["max_door_angle"].(f32) - 0.01
}

is_door_broken :: proc(ctx: ^BehaviorContext) -> bool {
    return ctx.blackboard["door_health"].(f32) <= 0
}

is_door_absent :: proc(ctx: ^BehaviorContext) -> bool {
    return ctx.blackboard["door_state"].(DoorState) == .ABSENT
}

// Physical impulse calculation for "roughly human shape" (rectangle)
calculate_collision_impulse :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    if !("collision_object" in ctx.blackboard) do return .SUCCESS

    door_angle := ctx.blackboard["door_angle"].(f32)
    door_pos := ctx.blackboard["door_position"].(Vec2)
    door_normal := Vec2{cos(door_angle), sin(door_angle)}

    object_pos := ctx.blackboard["collision_object_pos"].(Vec2)
    object_velocity := ctx.blackboard["collision_object_velocity"].(Vec2)
    object_mass := ctx.blackboard["collision_object_mass"].(f32)

    // Rectangle collision (simplified human shape: 0.6m x 1.8m)
    door_to_object := object_pos - door_pos
    penetration := dot(door_to_object, door_normal)

    if penetration > 0 && penetration < 0.6 { // Within "body width"
        // Calculate physical impulse
        relative_velocity := dot(object_velocity, door_normal)
        door_mass := ctx.blackboard["door_mass"].(f32)

        impulse_magnitude := -(1 + DOOR_RESTITUTION) * relative_velocity *
                           (object_mass * door_mass) / (object_mass + door_mass)

        ctx.blackboard["collision_impulse"] = door_normal * impulse_magnitude

        // Apply impulse to door swing
        door_impulse := impulse_magnitude / door_mass
        new_angle := clamp(door_angle + door_impulse * DOOR_SWING_FACTOR, 0,
                          ctx.blackboard["max_door_angle"].(f32))
        ctx.blackboard["door_angle"] = new_angle

        // Damage door based on impact force
        if abs(impulse_magnitude) > DOOR_DAMAGE_THRESHOLD {
            health := ctx.blackboard["door_health"].(f32)
            damage := abs(impulse_magnitude) * DOOR_DAMAGE_SCALE
            ctx.blackboard["door_health"] = max(0, health - damage)
        }

        // Generate physical environmental effects
        generate_impact_sound(ctx, impulse_magnitude)
        generate_dust_particles(ctx, door_pos, door_normal)
        create_air_pressure_wave(ctx, door_pos, new_angle - door_angle)
    }

    delete_key(&ctx.blackboard, "collision_object")
    return .SUCCESS
}

// Enhanced physical simulation: environmental effects
generate_impact_sound :: proc(ctx: ^BehaviorContext, force_magnitude: f32) {
    material, has_material := bb_get(ctx, "door_material", string)
    if !has_material do material = "wood"

    sound_intensity := clamp(abs(force_magnitude) * SOUND_SCALE, 0, 1)

    switch material {
    case "wood":
        if sound_intensity > 0.7 {
            bb_set(ctx, "door_sound", "wood_slam")
        } else if sound_intensity > 0.3 {
            bb_set(ctx, "door_sound", "wood_creak")
        }
    case "metal":
        if sound_intensity > 0.5 {
            bb_set(ctx, "door_sound", "metal_clang")
        }
    }

    bb_set(ctx, "sound_volume", sound_intensity)
}

generate_dust_particles :: proc(ctx: ^BehaviorContext, impact_pos: Vec2, normal: Vec2) {
    door_age, has_age := bb_get(ctx, "door_age", f32)
    if !has_age do door_age = 1.0

    if door_age > DUSTY_THRESHOLD {
        particle_count := int(door_age * DUST_PARTICLE_SCALE)
        particles := make([dynamic]Vec2)

        for i in 0..<particle_count {
            offset := Vec2{
                rand.float32_range(-0.5, 0.5),
                rand.float32_range(-0.5, 0.5),
            }
            append(&particles, impact_pos + offset)
        }

        bb_set(ctx, "dust_particles", particles)
        bb_set(ctx, "dust_direction", normal)
    }
}

create_air_pressure_wave :: proc(ctx: ^BehaviorContext, door_pos: Vec2, angle_delta: f32) {
    if abs(angle_delta) > AIR_MOVEMENT_THRESHOLD {
        // Door movement displaces air, creating pressure waves
        air_displacement := abs(angle_delta) * DOOR_AREA * AIR_DENSITY

        bb_set(ctx, "air_pressure_center", door_pos)
        bb_set(ctx, "air_pressure_magnitude", air_displacement)
        bb_set(ctx, "air_pressure_timer", AIR_PRESSURE_DURATION)

        // Affects nearby light sources (candles flicker, papers rustle)
        if air_displacement > LIGHT_FLICKER_THRESHOLD {
            bb_set(ctx, "nearby_lights_flicker", true)
        }

        // Temperature effects: draft creation
        if abs(angle_delta) > DRAFT_THRESHOLD {
            room_temp_diff, has_temp := bb_get(ctx, "room_temperature_difference", f32)
            if has_temp && abs(room_temp_diff) > 2.0 {
                bb_set(ctx, "cold_draft_intensity", abs(room_temp_diff) * DRAFT_SCALE)
                bb_set(ctx, "draft_direction", normal)
            }
        }
    }
}

// Hinge friction simulation
apply_hinge_friction :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    door_velocity := ctx.blackboard["door_angular_velocity"].(f32)
    friction_coeff := ctx.blackboard["hinge_friction"].(f32)

    // Apply friction force opposing motion
    friction_force := -door_velocity * friction_coeff
    ctx.blackboard["door_angular_velocity"] = door_velocity + friction_force * ctx.delta_time

    // Update door angle based on velocity
    door_angle := ctx.blackboard["door_angle"].(f32)
    new_angle := clamp(door_angle + door_velocity * ctx.delta_time, 0,
                      ctx.blackboard["max_door_angle"].(f32))
    ctx.blackboard["door_angle"] = new_angle

    return .RUNNING
}

// Mass-based swing calculation for small objects
calculate_small_object_swing :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    if !("small_impact" in ctx.blackboard) do return .SUCCESS

    impact_force := ctx.blackboard["small_impact_force"].(f32)
    impact_mass := ctx.blackboard["small_impact_mass"].(f32)
    door_mass := ctx.blackboard["door_mass"].(f32)

    // Small object: swing proportional to mass ratio and impact force
    mass_ratio := impact_mass / door_mass
    swing_amount := impact_force * mass_ratio * SMALL_OBJECT_SWING_SCALE

    door_angle := ctx.blackboard["door_angle"].(f32)
    new_angle := clamp(door_angle + swing_amount, 0, ctx.blackboard["max_door_angle"].(f32))
    ctx.blackboard["door_angle"] = new_angle

    delete_key(&ctx.blackboard, "small_impact")
    return .SUCCESS
}

handle_explosion_damage :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    explosion_force := ctx.blackboard["explosion_force"].(f32)

    if explosion_force > DOOR_DESTRUCTION_THRESHOLD {
        ctx.blackboard["door_state"] = DoorState.ABSENT
        ctx.blackboard["door_debris_velocity"] = Vec2{
            rand.float32_range(-10, 10),
            rand.float32_range(-10, 10),
        }
    } else {
        // Just damage the door
        health := ctx.blackboard["door_health"].(f32)
        ctx.blackboard["door_health"] = max(0, health - explosion_force * EXPLOSION_DAMAGE_SCALE)
    }

    delete_key(&ctx.blackboard, "explosion_force")
    return .SUCCESS
}

render_broken_door :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    // Broken door hangs at odd angle, reduces max swing
    ctx.blackboard["max_door_angle"] = ctx.blackboard["max_door_angle"].(f32) * 0.7
    ctx.blackboard["hinge_friction"] = ctx.blackboard["hinge_friction"].(f32) * 0.3
    return .RUNNING
}

// Build door physics behavior tree
door_tree := make_selector([dynamic]^BehaviorNode{
    make_sequence([dynamic]^BehaviorNode{
        make_condition(is_door_absent),
        make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult { return .SUCCESS }), // Do nothing
    }),
    make_sequence([dynamic]^BehaviorNode{
        make_condition(proc(ctx: ^BehaviorContext) -> bool { return "explosion_force" in ctx.blackboard }),
        make_action(handle_explosion_damage),
    }),
    make_sequence([dynamic]^BehaviorNode{
        make_condition(is_door_broken),
        make_action(render_broken_door),
    }),
    make_sequence([dynamic]^BehaviorNode{
        make_condition(proc(ctx: ^BehaviorContext) -> bool { return "small_impact" in ctx.blackboard }),
        make_action(calculate_small_object_swing),
    }),
    make_action(calculate_collision_impulse),
    make_action(apply_hinge_friction),
})
```

## Example 4: Emergent Swarm Intelligence (Generic Version)

```odin
// Individual nodes share global knowledge to create emergent collective behavior
SwarmRole :: enum {
    SCOUT,
    WORKER,
    GUARDIAN,
    COMMUNICATOR,
}

// Compile-time typed blackboard for swarm agents
SwarmBlackboard :: struct {
    // Individual agent state
    my_position: Vec2,
    my_role: SwarmRole,
    communication_range: f32,
    current_time: f32,

    // Local observations
    local_threat_detected: Maybe(Vec2),
    local_resource: Maybe(Vec2),

    // Shared swarm knowledge
    swarm_threats: [dynamic]Vec2,
    swarm_resources: [dynamic]Vec2,
    swarm_role_counts: map[SwarmRole]int,
    swarm_center: Vec2,
    unexplored_areas: [dynamic]Vec2,
    all_agent_positions: [dynamic]Vec2,

    // Movement calculations
    nearby_agents: [dynamic]Vec2,
    desired_velocity: Vec2,
    last_communication_time: f32,
}

// Each individual contributes to and reads from shared swarm mind
update_swarm_knowledge :: proc(ctx: ^BehaviorContext_Generic(SwarmBlackboard)) -> BehaviorResult {
    // Add personal observations to collective knowledge
    if "local_threat_detected" in ctx.blackboard {
        threat_pos := ctx.blackboard["local_threat_detected"].(Vec2)
        swarm_threats := &ctx.blackboard["swarm_threats"].([dynamic]Vec2)

        // Only add if not already known (simple deduplication)
        is_new := true
        for existing_threat in swarm_threats {
            if distance(threat_pos, existing_threat) < THREAT_MERGE_DISTANCE {
                is_new = false
                break
            }
        }
        if is_new do append(swarm_threats, threat_pos)

        delete_key(&ctx.blackboard, "local_threat_detected")
    }

    // Contribute personal resource discoveries
    if "local_resource" in ctx.blackboard {
        resource := ctx.blackboard["local_resource"].(Vec2)
        swarm_resources := &ctx.blackboard["swarm_resources"].([dynamic]Vec2)
        append(swarm_resources, resource)
        delete_key(&ctx.blackboard, "local_resource")
    }

    return .SUCCESS
}

// Dynamic role switching based on swarm needs
assess_swarm_needs :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    swarm_roles := ctx.blackboard["swarm_role_counts"].(map[SwarmRole]int)
    current_role := ctx.blackboard["my_role"].(SwarmRole)
    my_pos := ctx.blackboard["my_position"].(Vec2)

    // Calculate what role is most needed based on context
    needed_role := current_role
    max_need := 0.0

    // Scout need: unexplored areas vs scouts
    unexplored_weight := len(ctx.blackboard["unexplored_areas"].([dynamic]Vec2))
    scout_need := f32(unexplored_weight) / f32(max(1, swarm_roles[.SCOUT]))
    if scout_need > max_need {
        max_need = scout_need
        needed_role = .SCOUT
    }

    // Worker need: resources vs workers
    resources := ctx.blackboard["swarm_resources"].([dynamic]Vec2)
    worker_need := f32(len(resources)) / f32(max(1, swarm_roles[.WORKER]))
    if worker_need > max_need {
        max_need = worker_need
        needed_role = .WORKER
    }

    // Guardian need: threats vs guardians
    threats := ctx.blackboard["swarm_threats"].([dynamic]Vec2)
    guardian_need := f32(len(threats)) / f32(max(1, swarm_roles[.GUARDIAN]))
    if guardian_need > max_need {
        max_need = guardian_need
        needed_role = .GUARDIAN
    }

    // Switch role if need is significantly higher and we're not critical in current role
    if needed_role != current_role && max_need > ROLE_SWITCH_THRESHOLD {
        if swarm_roles[current_role] > 1 { // Don't leave role if we're the only one
            ctx.blackboard["my_role"] = needed_role
            swarm_roles[current_role] -= 1
            swarm_roles[needed_role] += 1
        }
    }

    return .SUCCESS
}

// Emergent flocking behavior with role-specific modifications
calculate_emergent_movement :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    my_pos := ctx.blackboard["my_position"].(Vec2)
    my_role := ctx.blackboard["my_role"].(SwarmRole)
    nearby_agents := ctx.blackboard["nearby_agents"].([dynamic]Vec2)

    // Base flocking: separation, alignment, cohesion
    separation := Vec2{0, 0}
    alignment := Vec2{0, 0}
    cohesion := Vec2{0, 0}

    for agent_pos in nearby_agents {
        to_agent := agent_pos - my_pos
        dist := length(to_agent)

        if dist < SEPARATION_RADIUS {
            separation -= normalize(to_agent) / dist // Stronger when closer
        }
        if dist < ALIGNMENT_RADIUS {
            // alignment += agent_velocity (would need velocity data)
        }
        if dist < COHESION_RADIUS {
            cohesion += to_agent
        }
    }

    if len(nearby_agents) > 0 {
        cohesion /= f32(len(nearby_agents))
    }

    // Role-specific behavior modifications
    role_vector := Vec2{0, 0}
    switch my_role {
    case .SCOUT:
        // Scouts are attracted to unexplored areas, repelled by other scouts
        unexplored := ctx.blackboard["unexplored_areas"].([dynamic]Vec2)
        if len(unexplored) > 0 {
            closest_unexplored := unexplored[0]
            min_dist := distance(my_pos, closest_unexplored)
            for area in unexplored[1:] {
                dist := distance(my_pos, area)
                if dist < min_dist {
                    min_dist = dist
                    closest_unexplored = area
                }
            }
            role_vector = normalize(closest_unexplored - my_pos) * SCOUT_EXPLORE_WEIGHT
        }

    case .WORKER:
        // Workers are attracted to resources
        resources := ctx.blackboard["swarm_resources"].([dynamic]Vec2)
        if len(resources) > 0 {
            closest_resource := resources[0]
            min_dist := distance(my_pos, closest_resource)
            for resource in resources[1:] {
                dist := distance(my_pos, resource)
                if dist < min_dist {
                    min_dist = dist
                    closest_resource = resource
                }
            }
            role_vector = normalize(closest_resource - my_pos) * WORKER_GATHER_WEIGHT
        }

    case .GUARDIAN:
        // Guardians are attracted to threats and form defensive positions
        threats := ctx.blackboard["swarm_threats"].([dynamic]Vec2)
        if len(threats) > 0 {
            // Move to intercept between threat and swarm center
            swarm_center := ctx.blackboard["swarm_center"].(Vec2)
            closest_threat := threats[0]
            // Position between threat and swarm
            intercept_pos := swarm_center + normalize(closest_threat - swarm_center) * GUARDIAN_INTERCEPT_DISTANCE
            role_vector = normalize(intercept_pos - my_pos) * GUARDIAN_PROTECT_WEIGHT
        }

    case .COMMUNICATOR:
        // Communicators try to maintain network connectivity
        role_vector = Vec2{0, 0} // Stay central to maintain connections
    }

    // Combine all forces
    final_direction := separation * SEPARATION_WEIGHT +
                      alignment * ALIGNMENT_WEIGHT +
                      cohesion * COHESION_WEIGHT +
                      role_vector

    ctx.blackboard["desired_velocity"] = normalize(final_direction) * BASE_SPEED
    return .RUNNING
}

// Emergent communication: agents relay information across the swarm
relay_information :: proc(ctx: ^BehaviorContext) -> BehaviorResult {
    my_pos := ctx.blackboard["my_position"].(Vec2)
    communication_range := ctx.blackboard["communication_range"].(f32)

    // Find agents in communication range
    all_agents := ctx.blackboard["all_agent_positions"].([dynamic]Vec2)
    in_range := make([dynamic]int)
    defer delete(in_range)

    for agent_pos, i in all_agents {
        if distance(my_pos, agent_pos) <= communication_range {
            append(&in_range, i)
        }
    }

    // Relay any important information to nearby agents
    if len(in_range) > 0 {
        // This would trigger information sharing between agents
        // In a real implementation, this would update their blackboards
        ctx.blackboard["last_communication_time"] = ctx.blackboard["current_time"]
    }

    return .SUCCESS
}

// Generic behavior tree construction with compile-time safety
swarm_agent_tree := make_sequence_generic(SwarmBlackboard, [dynamic]^BehaviorNode_Generic(SwarmBlackboard){
    make_action_generic(SwarmBlackboard, update_swarm_knowledge),
    make_action_generic(SwarmBlackboard, assess_swarm_needs),
    make_action_generic(SwarmBlackboard, calculate_emergent_movement),
    make_action_generic(SwarmBlackboard, relay_information),
})

// Demonstration of compile-time benefits:
execute_swarm_agent :: proc(agent_tree: ^BehaviorNode_Generic(SwarmBlackboard), blackboard: ^SwarmBlackboard) {
    ctx := BehaviorContext_Generic(SwarmBlackboard){
        blackboard = blackboard^,
        delta_time = 0.016, // 60 FPS
    }

    result := agent_tree.execute(agent_tree, &ctx)

    // No string-based access, no runtime type assertions!
    // IDE autocomplete works on ctx.blackboard.my_position, etc.
    // Typos in field names caught at compile time
    blackboard^ = ctx.blackboard // Write back changes
}

// Key differences with generic version:
// OLD: ctx.blackboard["my_position"].(Vec2)           NEW: ctx.blackboard.my_position
// OLD: "threat" in ctx.blackboard                     NEW: threat, has := ctx.blackboard.local_threat_detected.?
// OLD: delete_key(&ctx.blackboard, "threat")         NEW: ctx.blackboard.local_threat_detected = nil
// OLD: Runtime type panics possible                   NEW: Compile-time type checking
// OLD: No IDE autocomplete                            NEW: Full autocomplete support
// OLD: String typos cause runtime crashes             NEW: Field typos caught at compile-time

// For dynamic swarm systems, this provides:
// - Schema documentation (SwarmBlackboard shows all possible fields)
// - Performance improvements (struct access vs map lookup)
// - Development safety (typos/type errors caught early)
// - Better tooling support (refactoring, go-to-definition work properly)
```

## Example 5: API Improvements Summary

Based on implementing the examples above, two key improvements emerged:

1. **Composite Constructors**: Every example needed `make_sequence` and `make_selector` - these should be part of the core API rather than manually building nodes each time.

2. **Safe Blackboard Access**: The current `ctx.blackboard["key"].(Type)` pattern is verbose and error-prone. The `bb_get` and `bb_set` helpers provide type-safe access with proper error handling, making the behavior tree code much cleaner.

These additions maintain the essential simplicity while addressing the most common usage patterns discovered during implementation.

## Compile-Time Generic Improvement Proposal

The most impactful generic improvement would be parameterizing the behavior tree with a blackboard type:

```odin
BehaviorContext :: struct($BlackboardType: typeid) {
    blackboard: BlackboardType,
    delta_time: f32,
}

BehaviorNode :: struct($BlackboardType: typeid) {
    children: [dynamic]^BehaviorNode(BlackboardType),
    execute: proc(node: ^BehaviorNode(BlackboardType), context: ^BehaviorContext(BlackboardType)) -> BehaviorResult,
}

// Usage example:
EnemyBlackboard :: struct {
    enemy_pos: Vec2,
    player_pos: Vec2,
    enemy_facing: Vec2,
    move_direction: Vec2,
    last_noise_pos: Vec2,
    time_since_noise: f32,
}

enemy_ai: ^BehaviorNode(EnemyBlackboard)
```

**Benefits:**
- Compile-time type safety (no runtime type assertions)
- IDE autocomplete for blackboard fields
- No typos in field names
- Better performance (struct field access vs map lookup)
- Self-documenting blackboard schema

**Trade-off:** Less flexibility - each behavior tree needs its blackboard schema defined at compile-time. But this is often desirable for complex systems.

## [ Blind search algorithms ](https://www.youtube.com/watch?v=rBCzU-QC14w)

expand(node) -> []node
[]node: is a queue

depth-first search (data structure: stack)
breadth-first search (data structure: queue)

### uniform-cost search

Directed graph search algorithm that expands the least costly node first.
It uses a priority queue to store nodes based on the cumulative cost from the start node to the current node.

```odin
// cost of each edge. edges are directed.
store edges as enum{undirected, to, from, both}]

use a priority queue to expand nodes based on cost.
```

