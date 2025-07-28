package game

import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"

BehaviorNode :: struct {
	children: [dynamic]^BehaviorNode,
	execute:  proc(node: ^BehaviorNode, ctx: ^BehaviorContext) -> BehaviorResult,
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

// Core composites
sequence :: proc(node: ^BehaviorNode, ctx: ^BehaviorContext) -> BehaviorResult
selector :: proc(node: ^BehaviorNode, ctx: ^BehaviorContext) -> BehaviorResult

// Essential decorator
inverter :: proc(child: ^BehaviorNode) -> ^BehaviorNode

// Leaf constructors
make_action :: proc(action: proc(_: ^BehaviorContext) -> BehaviorResult) -> ^BehaviorNode
make_condition :: proc(condition: proc(_: ^BehaviorContext) -> bool) -> ^BehaviorNode

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
	execute:  proc(
		node: ^BehaviorNode_Generic(BlackboardType),
		ctx: ^BehaviorContext_Generic(BlackboardType),
	) -> BehaviorResult,
}

// Generic composite constructors
make_sequence_generic :: proc(
	$BlackboardType: typeid,
	children: [dynamic]^BehaviorNode_Generic(BlackboardType),
) -> ^BehaviorNode_Generic(BlackboardType) {
	node := new(BehaviorNode_Generic(BlackboardType))
	node.children = children
	node.execute =
	proc(
		n: ^BehaviorNode_Generic(BlackboardType),
		ctx: ^BehaviorContext_Generic(BlackboardType),
	) -> BehaviorResult {
		for child in n.children {
			result := child.execute(child, ctx)
			if result != .SUCCESS do return result
		}
		return .SUCCESS
	}
	return node
}

make_selector_generic :: proc(
	$BlackboardType: typeid,
	children: [dynamic]^BehaviorNode_Generic(BlackboardType),
) -> ^BehaviorNode_Generic(BlackboardType) {
	node := new(BehaviorNode_Generic(BlackboardType))
	node.children = children
	node.execute =
	proc(
		n: ^BehaviorNode_Generic(BlackboardType),
		ctx: ^BehaviorContext_Generic(BlackboardType),
	) -> BehaviorResult {
		for child in n.children {
			result := child.execute(child, ctx)
			if result != .FAILURE do return result
		}
		return .FAILURE
	}
	return node
}

// Generic leaf constructors
make_action_generic :: proc(
	$BlackboardType: typeid,
	action: proc(_: ^BehaviorContext_Generic(BlackboardType)) -> BehaviorResult,
) -> ^BehaviorNode_Generic(BlackboardType) {
	node := new(BehaviorNode_Generic(BlackboardType))
	node.execute =
	proc(
		n: ^BehaviorNode_Generic(BlackboardType),
		ctx: ^BehaviorContext_Generic(BlackboardType),
	) -> BehaviorResult {
		return action(ctx)
	}
	return node
}

make_condition_generic :: proc(
	$BlackboardType: typeid,
	condition: proc(_: ^BehaviorContext_Generic(BlackboardType)) -> bool,
) -> ^BehaviorNode_Generic(BlackboardType) {
	node := new(BehaviorNode_Generic(BlackboardType))
	node.execute =
	proc(
		n: ^BehaviorNode_Generic(BlackboardType),
		ctx: ^BehaviorContext_Generic(BlackboardType),
	) -> BehaviorResult {
		return .SUCCESS if condition(ctx) else .FAILURE
	}
	return node
}

// Console debugging visualization
behavior_tree_to_string_repr :: proc(
	node: ^BehaviorNode,
	depth: int = 0,
	is_last: bool = true,
	prefix: string = "",
) -> string {
	result := ""
	if node == nil do return result

	// Draw tree structure with Unicode box characters
	connector := "└── " if is_last else "├── "
	next_prefix := strings.concatenate({prefix, "    " if is_last else "│   "})

	// Node type and status indicators
	node_type := get_node_type_name(node)
	status_icon := get_status_icon(node)

	result = strings.concatenate({result, prefix, connector, status_icon, " ", node_type, "\n"})

	// Print children
	child_count := len(node.children)
	for child, i in node.children {
		is_last_child := (i == child_count - 1)
		child_string := behavior_tree_to_string_repr(child, depth + 1, is_last_child, next_prefix)
		result = strings.concatenate({result, child_string})
	}

	return result
}

get_status_icon :: proc(node: ^BehaviorNode) -> string {
	// Would need to track execution state, but for static representation:
	return "-" // Idle: -, Running: >, Success: +, Failure: !
}

get_node_type_name :: proc(node: ^BehaviorNode) -> string {
	// Would need node type tracking, simplified for demo:
	if len(node.children) == 0 do return "Action/Condition"
	if len(node.children) > 0 do return "Composite"
	return "Unknown"
}

// Enhanced debug version with live state
behavior_tree_debug_to_string :: proc(
	node: ^BehaviorNode,
	ctx: ^BehaviorContext,
	depth: int = 0,
	is_last: bool = true,
	prefix: string = "",
) -> string {
	result := ""
	if node == nil do return result

	connector := "└── " if is_last else "├── "
	next_prefix := strings.concatenate({prefix, "    " if is_last else "│   "})

	// Execute to get current status
	execution_result := node.execute(node, ctx)
	status_icon := ""
	status_color := ""

	switch execution_result {
	case .SUCCESS:
		status_icon = "+"
		status_color = "\033[32m" // Green
	case .FAILURE:
		status_icon = "!"
		status_color = "\033[31m" // Red
	case .RUNNING:
		status_icon = ">"
		status_color = "\033[33m" // Yellow
	}

	node_name := get_node_debug_name(node, ctx)
	reset_color := "\033[0m"

	result = strings.concatenate(
		{result, prefix, connector, status_color, status_icon, " ", node_name, reset_color, "\n"},
	)

	// Build children strings
	child_count := len(node.children)
	for child, i in node.children {
		is_last_child := (i == child_count - 1)
		child_string := behavior_tree_debug_to_string(
			child,
			ctx,
			depth + 1,
			is_last_child,
			next_prefix,
		)
		result = strings.concatenate({result, child_string})
	}

	return result
}

print_behavior_tree :: proc(node: ^BehaviorNode) {
	tree_string := behavior_tree_to_string_repr(node)
	fmt.print(tree_string)
}

print_behavior_tree_debug :: proc(node: ^BehaviorNode, ctx: ^BehaviorContext) {
	debug_string := behavior_tree_debug_to_string(node, ctx)
	fmt.print(debug_string)
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

// Unit Tests
@(test)
test_action_node_success :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	success_action := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "action_ran", true)
		return .SUCCESS
	})
	defer if success_action != nil do free(success_action)

	result := success_action.execute(success_action, &ctx)

	testing.expect_value(t, result, BehaviorResult.SUCCESS)
	ran, exists := bb_get(&ctx, "action_ran", bool)
	testing.expect(t, exists, "Action should have set blackboard value")
	testing.expect_value(t, ran, true)
}

@(test)
test_condition_node_true :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	bb_set(&ctx, "test_value", 42)

	condition := make_condition(proc(ctx: ^BehaviorContext) -> bool {
		value, exists := bb_get(ctx, "test_value", int)
		return exists && value == 42
	})
	defer if condition != nil do free(condition)

	result := condition.execute(condition, &ctx)
	testing.expect_value(t, result, BehaviorResult.SUCCESS)
}

@(test)
test_condition_node_false :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	condition := make_condition(proc(ctx: ^BehaviorContext) -> bool {
		return false
	})
	defer if condition != nil do free(condition)

	result := condition.execute(condition, &ctx)
	testing.expect_value(t, result, BehaviorResult.FAILURE)
}

@(test)
test_sequence_all_success :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	action1 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step1", true)
		return .SUCCESS
	})
	defer if action1 != nil do free(action1)

	action2 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step2", true)
		return .SUCCESS
	})
	defer if action2 != nil do free(action2)

	children := make([dynamic]^BehaviorNode)
	append(&children, action1, action2)
	defer delete(children)

	sequence := make_sequence(children)
	defer {
		if sequence != nil {
			delete(sequence.children)
			free(sequence)
		}
	}

	result := sequence.execute(sequence, &ctx)

	testing.expect_value(t, result, BehaviorResult.SUCCESS)

	step1, _ := bb_get(&ctx, "step1", bool)
	step2, _ := bb_get(&ctx, "step2", bool)
	testing.expect_value(t, step1, true)
	testing.expect_value(t, step2, true)
}

@(test)
test_sequence_early_failure :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	action1 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step1", true)
		return .FAILURE
	})
	defer if action1 != nil do free(action1)

	action2 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step2", true)
		return .SUCCESS
	})
	defer if action2 != nil do free(action2)

	children := make([dynamic]^BehaviorNode)
	append(&children, action1, action2)
	defer delete(children)

	sequence := make_sequence(children)
	defer {
		if sequence != nil {
			delete(sequence.children)
			free(sequence)
		}
	}

	result := sequence.execute(sequence, &ctx)

	testing.expect_value(t, result, BehaviorResult.FAILURE)

	step1, _ := bb_get(&ctx, "step1", bool)
	step2_exists := "step2" in ctx.blackboard
	testing.expect_value(t, step1, true)
	testing.expect(t, !step2_exists, "Second action should not have run")
}

@(test)
test_selector_first_success :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	action1 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step1", true)
		return .SUCCESS
	})
	defer if action1 != nil do free(action1)

	action2 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step2", true)
		return .SUCCESS
	})
	defer if action2 != nil do free(action2)

	children := make([dynamic]^BehaviorNode)
	append(&children, action1, action2)
	defer delete(children)

	selector := make_selector(children)
	defer {
		if selector != nil {
			delete(selector.children)
			free(selector)
		}
	}

	result := selector.execute(selector, &ctx)

	testing.expect_value(t, result, BehaviorResult.SUCCESS)

	step1, _ := bb_get(&ctx, "step1", bool)
	step2_exists := "step2" in ctx.blackboard
	testing.expect_value(t, step1, true)
	testing.expect(t, !step2_exists, "Second action should not have run")
}

@(test)
test_selector_fallback :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	action1 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step1", true)
		return .FAILURE
	})
	defer if action1 != nil do free(action1)

	action2 := make_action(proc(ctx: ^BehaviorContext) -> BehaviorResult {
		bb_set(ctx, "step2", true)
		return .SUCCESS
	})
	defer if action2 != nil do free(action2)

	children := make([dynamic]^BehaviorNode)
	append(&children, action1, action2)
	defer delete(children)

	selector := make_selector(children)
	defer {
		if selector != nil {
			delete(selector.children)
			free(selector)
		}
	}

	result := selector.execute(selector, &ctx)

	testing.expect_value(t, result, BehaviorResult.SUCCESS)

	step1, _ := bb_get(&ctx, "step1", bool)
	step2, _ := bb_get(&ctx, "step2", bool)
	testing.expect_value(t, step1, true)
	testing.expect_value(t, step2, true)
}

@(test)
test_blackboard_helpers :: proc(t: ^testing.T) {
	ctx := BehaviorContext {
		blackboard = make(map[string]any),
		delta_time = 0.016,
	}
	defer delete(ctx.blackboard)

	// Test bb_set and bb_get with different types
	bb_set(&ctx, "int_val", 42)
	bb_set(&ctx, "float_val", 3.14)
	bb_set(&ctx, "string_val", "hello")
	bb_set(&ctx, "bool_val", true)

	// Test successful retrieval
	int_val, int_exists := bb_get(&ctx, "int_val", int)
	testing.expect(t, int_exists, "int value should exist")
	testing.expect_value(t, int_val, 42)

	float_val, float_exists := bb_get(&ctx, "float_val", f32)
	testing.expect(t, float_exists, "float value should exist")
	testing.expect_value(t, float_val, f32(3.14))

	string_val, string_exists := bb_get(&ctx, "string_val", string)
	testing.expect(t, string_exists, "string value should exist")
	testing.expect_value(t, string_val, "hello")

	// Test missing key
	missing_val, missing_exists := bb_get(&ctx, "nonexistent", int)
	testing.expect(t, !missing_exists, "nonexistent key should return false")
	testing.expect_value(t, missing_val, 0) // default value
}

