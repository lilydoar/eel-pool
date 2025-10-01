# Debug Text Stack String Lifetime Management Report

## Executive Summary

This report analyzes the current debug text stack implementation and provides recommendations for convenient string creation with proper frame-scoped lifetime management. The goal is to enable easy creation of debug strings that remain valid throughout a frame but are automatically reset between frames.

## Current Implementation Analysis

### Debug Text Stack Structure

The current `Debug_Text_Stack` (src/debug.odin:61-66) contains:

```odin
Debug_Text_Stack :: struct {
    cfg:            Debug_Text_Stack_Config,
    string_builder: strings.Builder,        // ← Currently unused!
    stack_text:     [dynamic]string,
    stack_cursor:   Vec2i,
}
```

### Current String Creation Pattern

**Location:** src/game.odin:143-144, 222, 228
```odin
// In game_init:
sbuf: [1024]u8
sb := strings.builder_from_bytes(sbuf[:])

// In game_update:
dbg_txt_stack_push(&game.debug.debug_text_stack, fmt.sbprintfln(&sb, "hello world"))
dbg_txt_stack_push(&game.debug.debug_text_stack, fmt.sbprintfln(&sb, "game_state: %v", game))
```

### Frame Lifecycle

1. **Frame Start:** `dbg_txt_stack_reset()` clears stack and resets internal builder (src/game.odin:219)
2. **Frame Update:** Multiple `dbg_txt_stack_push()` calls with formatted strings
3. **Frame Render:** `dbg_txt_stack_draw()` renders all accumulated strings (src/game.odin:456)

### Issues with Current Approach

1. **Unused Infrastructure**: Each debug stack has a `string_builder` that gets reset but never used
2. **External Builder Dependency**: Relies on an external string builder `sb` with unclear lifetime
3. **Memory Safety Concerns**: No guarantee strings remain valid between creation and rendering
4. **Manual Buffer Management**: Fixed 1024-byte buffer may be insufficient for complex debug output

## Odin String Management Capabilities

### Core/Strings Package Features

- **Builder Pattern**: `strings.Builder` with dynamic allocation
- **Memory Control**: Context-based allocators with `builder_reset()` and `builder_destroy()`
- **Buffer Management**: `builder_from_bytes()` for fixed-size buffers
- **String Creation**: `to_string()` for extracting current content

### Core/Fmt Package Features

- **String Builder Integration**: `sbprintf` family writes directly to builders
- **Memory Allocation Options**:
  - Context allocator (persistent)
  - Temporary allocator (auto-cleanup)
  - Custom allocators
- **Format Functions**: `sbprintfln()` appends newlines automatically

## Recommended Solutions

### Solution 1: Utilize Built-in String Builder (Recommended)

**Concept**: Use the existing `string_builder` field in `Debug_Text_Stack` for all string creation.

**Implementation:**

```diff
# src/debug.odin modifications

+dbg_txt_stack_printf :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any) {
+    start_pos := len(dbg.string_builder.buf)
+    fmt.sbprintf(&dbg.string_builder, format, ..args)
+    end_pos := len(dbg.string_builder.buf)
+
+    // Create string slice pointing into builder's buffer
+    text := string(dbg.string_builder.buf[start_pos:end_pos])
+    append(&dbg.stack_text, text)
+
+    switch dbg.cfg.axis {
+    case .horizontal: dbg.stack_cursor.x += dbg.cfg.step_size
+    case .vertical:   dbg.stack_cursor.y += dbg.cfg.step_size
+    }
+}
+
+dbg_txt_stack_printfln :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any) {
+    dbg_txt_stack_printf(dbg, format, ..args)
+    strings.write_byte(&dbg.string_builder, '\n')
+}
```

**Usage:**
```diff
# src/game.odin modifications

-sbuf: [1024]u8
-sb := strings.builder_from_bytes(sbuf[:])

-dbg_txt_stack_push(&game.debug.debug_text_stack, fmt.sbprintfln(&sb, "hello world"))
+dbg_txt_stack_printfln(&game.debug.debug_text_stack, "hello world")

-dbg_txt_stack_push(&game.debug.debug_text_stack, fmt.sbprintfln(&sb, "game_state: %v", game))
+dbg_txt_stack_printfln(&game.debug.debug_text_stack, "game_state: %v", game)
```

**Benefits:**
- Eliminates external string builder dependency
- Guaranteed string lifetime (valid until `dbg_txt_stack_reset()`)
- Automatic memory management
- Cleaner API

### Solution 2: Enhanced Builder with Temporary Storage

**Concept**: Create a more sophisticated string management system with temporary string storage.

```odin
Debug_Text_Stack :: struct {
    cfg:            Debug_Text_Stack_Config,
    string_builder: strings.Builder,
    temp_strings:   [dynamic]string,    // ← New: temporary string storage
    stack_text:     [dynamic]string,
    stack_cursor:   Vec2i,
}

dbg_txt_stack_create_string :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any) -> string {
    start_len := len(dbg.string_builder.buf)
    fmt.sbprintf(&dbg.string_builder, format, ..args)
    end_len := len(dbg.string_builder.buf)

    result := string(dbg.string_builder.buf[start_len:end_len])
    append(&dbg.temp_strings, result)
    return result
}
```

### Solution 3: Context Allocator with Automatic Cleanup

**Concept**: Use Odin's temporary allocator for automatic cleanup.

```odin
dbg_txt_stack_printf_temp :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any) {
    context.allocator = context.temp_allocator
    text := fmt.tprintf(format, ..args)  // Uses temporary allocator
    append(&dbg.stack_text, text)

    switch dbg.cfg.axis {
    case .horizontal: dbg.stack_cursor.x += dbg.cfg.step_size
    case .vertical:   dbg.stack_cursor.y += dbg.cfg.step_size
    }
}
```

## Performance Considerations

### Memory Allocation Patterns

1. **Built-in Builder (Solution 1)**:
   - Single allocation per frame (builder growth)
   - No per-string allocations
   - Excellent cache locality

2. **Temporary Allocator (Solution 3)**:
   - Multiple small allocations
   - Automatic cleanup
   - Potential fragmentation

### Benchmark Estimates

For typical debug output (10-20 strings per frame):
- **Solution 1**: ~1 allocation/frame + occasional buffer growth
- **Solution 3**: ~10-20 allocations/frame

## Migration Strategy

### Phase 1: Implement Enhanced API
```odin
// Add new functions alongside existing ones
dbg_txt_stack_printf :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any)
dbg_txt_stack_printfln :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any)
```

### Phase 2: Update Call Sites
```diff
-dbg_txt_stack_push(&game.debug.debug_text_stack, fmt.sbprintfln(&sb, "hello world"))
+dbg_txt_stack_printfln(&game.debug.debug_text_stack, "hello world")
```

### Phase 3: Remove External Builder
```diff
-sbuf: [1024]u8
-sb := strings.builder_from_bytes(sbuf[:])
```

## Conclusion

**Recommended Approach**: Solution 1 (Built-in String Builder)

This approach:
- ✅ Leverages existing infrastructure
- ✅ Provides guaranteed string lifetime
- ✅ Eliminates external dependencies
- ✅ Offers superior performance
- ✅ Maintains clean, simple API

The built-in string builder approach provides the perfect balance of convenience, performance, and safety for frame-scoped debug string management while utilizing the existing `Debug_Text_Stack` infrastructure more effectively.

## Example Implementation

Here's a complete implementation of the recommended solution:

```odin
// Enhanced debug text stack functions
dbg_txt_stack_printf :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any) {
    start_pos := len(dbg.string_builder.buf)
    fmt.sbprintf(&dbg.string_builder, format, ..args)
    end_pos := len(dbg.string_builder.buf)

    text := string(dbg.string_builder.buf[start_pos:end_pos])
    append(&dbg.stack_text, text)

    switch dbg.cfg.axis {
    case .horizontal: dbg.stack_cursor.x += dbg.cfg.step_size
    case .vertical:   dbg.stack_cursor.y += dbg.cfg.step_size
    }
}

dbg_txt_stack_printfln :: proc(dbg: ^Debug_Text_Stack, format: string, args: ..any) {
    dbg_txt_stack_printf(dbg, format, ..args)
    if len(dbg.string_builder.buf) > 0 &&
       dbg.string_builder.buf[len(dbg.string_builder.buf)-1] != '\n' {
        strings.write_byte(&dbg.string_builder, '\n')
    }
}

// Convenience function for simple strings
dbg_txt_stack_print :: proc(dbg: ^Debug_Text_Stack, text: string) {
    start_pos := len(dbg.string_builder.buf)
    strings.write_string(&dbg.string_builder, text)
    end_pos := len(dbg.string_builder.buf)

    result := string(dbg.string_builder.buf[start_pos:end_pos])
    append(&dbg.stack_text, result)

    switch dbg.cfg.axis {
    case .horizontal: dbg.stack_cursor.x += dbg.cfg.step_size
    case .vertical:   dbg.stack_cursor.y += dbg.cfg.step_size
    }
}
```

This implementation ensures strings remain valid throughout the frame and are automatically cleaned up via the existing `dbg_txt_stack_reset()` mechanism.
