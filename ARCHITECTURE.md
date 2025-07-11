# JJ-NVIM Architecture Documentation

## Overview

This document describes the architecture, command execution flows, and optimization recommendations for the jj-nvim plugin after thorough refactoring to eliminate redundant code patterns.

## Core Architecture Components

### 1. Entry Point Layer
- **`init.lua`**: Main plugin interface with `setup()`, `toggle()`, `show_log()`, `refresh()`, and `close()` functions
- **Primary API**: User-facing commands and plugin lifecycle management

### 2. Command Execution Layer
- **`jj/commands.lua`**: Core jj CLI command execution with timeout, async support, and error handling
- **`jj/command_utils.lua`**: Unified command utilities for validation, error handling, and common patterns
- **Pattern**: All jj operations flow through centralized execution functions

### 3. Data Processing Layer
- **`core/parser.lua`**: Parse jj output using template system to extract commit data and graph structure
- **`core/renderer.lua`**: Apply syntax highlighting and format output for display
- **`core/commit.lua`**: Commit object utilities and data access methods

### 4. UI Management Layer
- **`ui/buffer.lua`**: Create and manage the log buffer with status display
- **`ui/window.lua`**: Handle window creation, keymaps, and interaction modes
- **`ui/navigation.lua`**: Cursor movement and selection within the log
- **`ui/action_menu.lua`**: Context-sensitive action menu system
- **`ui/context_window.lua`**: Auto-showing context window for available actions

### 5. Operation Layer
- **`jj/actions.lua`**: Central coordinator for all jj operations with UI integration
- **Individual Command Modules**: Specialized implementations for each jj operation
- **`jj/buffer_utils.lua`**: Unified buffer creation and display utilities

### 6. Utility Layer
- **`utils/`**: Cross-cutting concerns (validation, error handling, persistence, etc.)
- **`utils/menu_utils.lua`**: Standardized menu configuration and creation patterns

## Unified Command Execution Flow

### 1. Primary Parse/Render Cycle
```
User Action → init.lua:show_log()
  ↓
parser.parse_commits_with_separate_graph()
  ├─ jj log --template "commit_data" (structured data)
  └─ jj log --template "graph_markers" (graph structure)
  ↓
Data merge → commit objects
  ↓
buffer.create_from_commits() → renderer.render_with_highlights()
  ↓
Buffer display with ANSI highlighting + status info
```

### 2. Action Execution Flow
```
User Action → actions.{operation}
  ↓
command_utils.validate_commit() → command_utils.get_change_id()
  ↓
{operation_module}.{operation}()
  ├─ command_utils.build_command_args() (unified arg building)
  ├─ command_utils.execute_with_error_handling() (unified execution)
  └─ Standardized error pattern mapping
  ↓
Success notification → init.refresh() → Parse/Render Cycle
```

### 3. Interactive Operation Flow
```
User Action → {operation}.show_{operation}_menu()
  ↓
menu_utils.create_operation_menu() (standardized menu creation)
  ↓
inline_menu.show() → handle_menu_selection()
  ↓
window.enter_target_selection_mode() [if needed]
  ↓
command_utils.execute_with_error_handling()
  ├─ Interactive: command_utils.create_interactive_callbacks()
  └─ Input prompts: command_utils.prompt_for_input()
  ↓
Auto-refresh on completion
```

### 4. Multi-Select Operation Flow
```
User triggers multi-select → window.enter_multi_select_mode()
  ↓
multi_select.toggle_commit_selection() [repeat]
  ↓
window.confirm_multi_selection()
  ↓
actions.{operation}_multiple_commits()
  ├─ command_utils.validate_multiple_commits()
  └─ command_utils.build_commit_summaries()
  ↓
Bulk command execution → init.refresh()
```

### 5. Unified View Toggle Flow
```
User triggers view toggle (Ctrl+T/Tab) → window.toggle_view()
  ↓
View state management → window.set_view()
  ├─ Log View: Uses commit parsing and rendering
  └─ Bookmark View: Uses bookmark fetching and unified rendering
  ↓
Unified content interface
  ├─ Navigation: view-aware line calculation
  ├─ Highlighting: unified object highlighting
  └─ Selection: content-type aware operations
  ↓
Single render cycle → status + content update atomically
```

#### Unified Content Object Interface
- **Commits**: `{line_start, line_end, content_type: "commit", change_id, ...}`
- **Bookmarks**: `{line_start, line_end, content_type: "bookmark", commit_id, ...}`
- **Navigation**: `get_navigable_lines()` returns view-appropriate line positions
- **Highlighting**: Works transparently with both content types using same properties

## Consolidated Patterns

### 1. Command Execution Utilities (`command_utils.lua`)

#### Unified Command Building
- **`build_command_args(base_command, common_options, specific_options)`**
- Eliminates repetitive command argument construction
- Handles common flags: `--interactive`, `--tool`, `--message`, `--revision`, `--destination`

#### Standardized Error Handling
- **`execute_with_error_handling(cmd_args, error_context, options)`**
- **`execute_with_error_handling_async(cmd_args, error_context, options, callback)`**
- Common error pattern mapping across all operations
- Consistent user-friendly error messages

#### Interactive Command Support
- **`create_interactive_callbacks(operation_name, display_id)`**
- Standardized callback patterns for interactive operations
- Eliminates duplicate callback code in squash.lua, split.lua, commit.lua

#### Input Prompting
- **`prompt_for_input(config)`**
- Unified vim.ui.input wrapper with validation and cancellation handling
- Replaces repetitive input prompt patterns

#### Validation and Utilities
- **`validate_commit(commit, options)`** - Centralized commit validation
- **`validate_multiple_commits(commit_ids, validation_options)`** - Multi-commit validation
- **`get_change_id(commit)`** - Standardized change ID extraction
- **`get_target_display_name(target, target_type)`** - Unified display name generation

### 2. Buffer Management Utilities (`buffer_utils.lua`)

#### Unified Buffer Creation
- **`create_buffer_with_ansi(content, buffer_name, filetype, options)`**
- ANSI color processing and syntax highlighting setup
- Eliminates duplicate buffer creation patterns

#### Display Management
- **`display_buffer(buf_id, display_mode, split_direction, config_key, options)`**
- **`display_buffer_split()` / `display_buffer_float()`**
- Unified split vs floating window handling

#### Complete Workflow
- **`create_and_display_buffer(content, buffer_name, display_config)`**
- End-to-end buffer creation, display, and keymap setup

### 3. Menu Utilities (`menu_utils.lua`)

#### Standardized Menu Creation
- **`create_operation_menu(operation_name, menu_items_config, options)`**
- **`get_menu_keybinds(menu_name, fallback_keys)`**
- Consistent menu configuration across operations

#### Common Menu Patterns
- **`create_standard_operation_items(operation_name)`** - Quick/Interactive/Message options
- **`create_target_selection_items(operation_name, target_types)`** - Target selection menus

## Data Flow Architecture

### Command Registry Pattern
Each jj operation follows a standardized interface:

```lua
-- Standard operation signature
{operation}_module.{operation} = function(source, target, options)
  -- 1. Validation
  local is_valid, err = command_utils.validate_commit(source)
  
  -- 2. Command building
  local cmd_args = command_utils.build_command_args(
    operation_name, 
    common_options, 
    specific_options
  )
  
  -- 3. Execution
  return command_utils.execute_with_error_handling(
    cmd_args, 
    operation_name, 
    options
  )
end
```

### Refresh Strategy
- **Centralized Refresh**: All operations trigger `require('jj-nvim').refresh()`
- **Auto-refresh**: Interactive operations refresh automatically via terminal callbacks
- **Error Recovery**: Failed operations don't trigger refresh to maintain current state

## Performance Optimizations

### 1. Command Execution
- **Async Support**: All operations support async execution where applicable
- **Timeout Management**: 30-second timeout for synchronous operations
- **Interactive Optimization**: Interactive commands use native terminal interface

### 2. Parsing Efficiency
- **Dual-parsing Strategy**: Separate template and graph parsing for optimal data extraction
- **Template-based Parsing**: Uses jj's native template system for reliable structured data
- **Graph Preservation**: Maintains ASCII graph structure from jj's output

### 3. UI Performance
- **ANSI Processing**: Efficient ANSI color parsing and highlight application
- **Buffer Reuse**: Smart buffer management with unique naming and cleanup
- **Window Management**: Optimized window positioning and configuration

## Extension Points

### 1. New Command Integration
To add a new jj operation:

1. Create module in `jj/{operation}.lua`
2. Use `command_utils.build_command_args()` for command construction
3. Use `command_utils.execute_with_error_handling()` for execution
4. Add action wrapper in `jj/actions.lua`
5. Register in action menu system

### 2. Custom Menu Systems
Use `menu_utils.create_operation_menu()` with custom menu item configurations:

```lua
local menu_items = {
  {
    key_name = "custom_action",
    default_key = "c",
    description = "Custom operation",
    action = "custom"
  }
}
```

### 3. Buffer Display Modes
Extend `buffer_utils.create_and_display_buffer()` with custom display configurations:

```lua
local display_config = {
  filetype = "custom",
  display_mode = "float",
  config_key = "custom.float",
  close_keymap_prefix = "keybinds.custom_window"
}
```

## Optimization Recommendations

### 1. Completed Optimizations
- ✅ **Unified Command Execution**: Consolidated command building and error handling
- ✅ **Standardized Input Patterns**: Eliminated repetitive vim.ui.input code
- ✅ **Interactive Callback Consolidation**: Unified callback patterns
- ✅ **Buffer Management Unification**: Single buffer creation and display workflow
- ✅ **Unified View System**: Seamless toggling between log and bookmark views
- ✅ **Content Interface Standardization**: Common properties for all content types
- ✅ **Single Render Cycle**: Atomic status and content updates

### 2. Future Optimization Opportunities

#### Phase 1: Advanced View System Enhancement
- Implement view state persistence across sessions
- Add custom view filtering and sorting options
- Enhanced bookmark management capabilities

#### Phase 2: Command Registry System
```lua
-- Proposed command registry
local operation_registry = {
  abandon = {
    type = "destructive",
    requires_confirmation = true,
    allows_multi_commit = true,
    validates_non_root = true,
    error_patterns = { ... },
    menu_config = { ... }
  }
}
```

#### Phase 3: Performance Enhancement
- Implement refresh batching to avoid redundant parsing
- Add refresh failure recovery mechanisms
- Smart refresh triggers based on operation impact
- Optimize view switching performance for large repositories

#### Phase 4: Error Handling Enhancement
- Operation-specific error recovery strategies
- Better conflict resolution workflows
- Enhanced error context and suggestions
- View-aware error handling and recovery

### 3. Code Quality Metrics

#### Before Refactoring
- **Duplicate Code**: ~200 lines of repetitive patterns across 8 command modules
- **Error Handling**: Inconsistent error message formatting and handling
- **Input Prompts**: 15+ similar vim.ui.input patterns with minor variations
- **Command Building**: Repetitive argument construction in 6+ modules
- **View Management**: Separate rendering paths for different content types

#### After Refactoring + Unified View System
- **Code Reduction**: ~150 lines consolidated into utility functions
- **Consistency**: Standardized error messages and user experience
- **Maintainability**: Single source of truth for common patterns
- **Extensibility**: Clear extension points for new operations
- **Unified Interface**: Single rendering system for all content types
- **View Toggle**: Seamless switching between log and bookmark views
- **Performance**: Single render cycle eliminates content conflicts

## Testing Strategy

### 1. Utility Function Testing
- Test `command_utils` functions with various input scenarios
- Validate error handling and edge cases
- Test async callback behavior

### 2. Integration Testing
- Verify refactored commands maintain original functionality
- Test menu generation and interaction flows
- Validate buffer creation and display modes

### 3. Performance Testing
- Measure command execution times before/after refactoring
- Test memory usage with large commit histories
- Validate async operation performance

## Conclusion

The jj-nvim architecture now provides a solid foundation for consistent command execution while maintaining the plugin's feature-rich functionality. The refactoring has eliminated significant code duplication while preserving all existing behavior, resulting in a more maintainable and extensible codebase.

The unified command execution flow ensures consistent user experience across all jj operations, while the consolidated utility functions provide clear patterns for future development. The architecture is well-positioned for continued growth and enhancement while maintaining code quality and performance.