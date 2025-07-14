# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# JJ-Nvim Plugin Development

## Implementation Principles

- Avoid writing new code when at all possible. Always look for existing code/workflows to leverage when adding new features.
- Always look for opportunities to refactor repeated code as long as it doesn't change functionality
- Ask questions liberally to clarify
- When you have multiple questions, ask them one by one, and try to answer your own questions based on existing context
- Don't mention yourself in commit messages
- Write tests for new work, integrating with the testing framework in tests/. Prioritize writing official tests to test your own work instead of creating one-off test files that you then remove after running them.

- After you've implemented work, ask if you want to commit the changes. If yes, run 'jj commit' with a message that is a good commit message for the changes made.

- Don't add feedback via notifications for actions that change the UI somehow. Notifications are redundant and clutter things in these cases since the UI reflects the action taken.

- Don't limit the number of lines you get from help commands with --head. Read the entire help document.

## Project Overview

A Neovim plugin for interacting with the jujutsu (jj) version control system through an interactive log interface. The plugin displays a graphical commit log with graph visualization, interactive navigation, and commit operations.

## Architecture

**📖 For detailed architecture documentation, command execution flows, and optimization recommendations, see [ARCHITECTURE.md](ARCHITECTURE.md).**

**📋 For command menu structures and user interaction flows, see [MENU_STRUCTURES.md](MENU_STRUCTURES.md).**

### Core Components

- **Entry Point** (`lua/jj-nvim/init.lua`\): Main plugin interface with `setup()`, `toggle()`, `show_log()`, and `close()` functions
- **Parser** (`lua/jj-nvim/core/parser.lua`\): Parses jj command output using template system to extract commit data and graph structure
- **Renderer** (`lua/jj-nvim/core/renderer.lua`\): Renders parsed commits with syntax highlighting and graph visualization
- **Commands** (`lua/jj-nvim/jj/commands.lua`\): Wrapper for executing jj CLI commands via `vim.system()`
- **UI Components**:
  - **Buffer** (`lua/jj-nvim/ui/buffer.lua`\): Creates and manages the log buffer with unified content support
  - **Window** (`lua/jj-nvim/ui/window.lua`\): Handles window creation, view management, and unified selection modes
  - **Navigation** (`lua/jj-nvim/ui/navigation.lua`\): View-aware cursor movement and selection
- **Configuration** (`lua/jj-nvim/config.lua`\): Plugin settings with persistence support

### Data Flow

1. User triggers `JJToggle` or `JJLog` command
2. Parser executes `jj log` with custom template to extract commit metadata
3. Separate `jj log --graph` call retrieves ASCII graph structure
4. Parser combines template data with graph structure into commit objects
5. Renderer applies syntax highlighting and formatting
6. Buffer and Window components display the results

### Key Design Patterns

- **Separation of Concerns**: Graph parsing, data extraction, and rendering are handled by separate modules
- **Template-Based Parsing**: Uses jj's template system for reliable structured data extraction
- **Graph Preservation**: Maintains ASCII graph structure from jj's native output
- **Error Handling**: Comprehensive error checking with user-friendly messages
- **Unified Command Execution**: Consolidated command building, error handling, and execution patterns (see ARCHITECTURE.md)
- **Unified Content Interface**: Common object structure for commits and bookmarks enabling seamless view switching
- **Single Render Cycle**: Atomic status and content updates to prevent conflicts
- **Utility-First Design**: Common patterns extracted into reusable utility modules

## Development Commands

### Testing

```bash
# Run basic functionality tests (requires being in a jj repository)
lua tests/run_tests.lua

# Test specific components (from within Neovim)
:lua require('jj-nvim.tests.test_parser')
```

### Plugin Installation Testing

```vim
" Add to init.vim/init.lua for local development
set runtimepath+=~/path/to/jj-nvim
```

## File Structure

```
lua/jj-nvim/
├── init.lua              # Main plugin entry point
├── config.lua            # Configuration management
├── core/
│   ├── commit.lua        # Commit object utilities
│   ├── parser.lua        # jj output parsing
│   └── renderer.lua      # Syntax highlighting and rendering
├── jj/
│   ├── actions.lua       # Git operations (diff, edit, abandon)
│   ├── commands.lua      # jj CLI command execution
│   └── log.lua           # Log retrieval (legacy)
├── ui/
│   ├── buffer.lua        # Buffer management
│   ├── window.lua        # Window positioning
│   ├── navigation.lua    # Cursor movement
│   ├── inline_menu.lua   # Interactive menus
│   ├── multi_select.lua  # Multi-selection support
│   ├── action_menu.lua   # Context-sensitive action menu
│   ├── context_window.lua # Auto-showing context window
│   └── themes.lua        # Theme management
├── themes/               # Color schemes
└── utils/                # Utility modules
```

## Implementation Notes

### Parser Architecture

The plugin uses a dual-parsing approach:

1. **Template parsing** for structured commit data (ID, author, description, etc.)
2. **Graph parsing** for ASCII graph structure preservation

### Graph Wrapping Challenge

The plugin previously attempted graph-aware text wrapping but this was disabled due to complexity. See `GRAPH_WRAPPING_RESEARCH.md` for details on the technical challenges discovered.

### Action Menu & Context Window System

The plugin features a discoverable action system with two complementary interfaces:

#### Context Window (`lua/jj-nvim/ui/context_window.lua`)
Auto-showing floating window that displays available actions within the log window:
- **Auto-show**: Appears when selections are made, disappears when cleared
- **Real-time updates**: Updates content based on cursor position and selections
- **Window-relative**: Positioned within the log window bounds, not the entire screen
- **Configurable**: Position (top/bottom/left/right), size, and auto-show behavior
- **Non-intrusive**: Non-focusable, stays out of the way during normal operation
- **View-aware**: Shows appropriate actions for current view (log or bookmark)

#### Action Menu (`lua/jj-nvim/ui/action_menu.lua`)
Interactive menu for manual action selection:
- **Context-aware**: Shows different actions based on current selection state
- **No selections**: Shows actions for commit under cursor (diff, edit, abandon, etc.)
- **Single selection**: Shows actions for the selected commit
- **Multiple selections**: Shows multi-commit actions (abandon multiple, rebase multiple)
- **Smart validation**: Disables invalid actions (e.g., can't abandon root commit)
- **Default keybinding**: `<leader>a` (configurable via `keybinds.log_window.actions.action_menu`)
- **Mixed selection support**: Handles operations involving both commits and bookmarks

Both systems work together to provide maximum discoverability while maintaining a clean interface.

### Unified View Toggle System

The plugin features a unified view toggle system that allows switching between commit log and bookmark views:

#### Architecture
- **Unified Content Interface**: Both commits and bookmarks implement the same interface (`line_start`, `line_end`, `content_type`)
- **View-Aware Navigation**: Navigation functions automatically handle commit vs bookmark navigation
- **Single Render Cycle**: Status and content update atomically to prevent overwrites
- **Tight Coupling**: Navigation, highlighting, and rendering use identical object instances

#### View Types
- **Log View**: Standard commit log with graph visualization
- **Bookmark View**: Clean list of present bookmarks in jj-native format (`name@remote change_id`)

#### Usage
- **Keybinds**: `Ctrl+T` or `Tab` to toggle between views
- **Availability**: Only enabled in target selection and multi-select modes
- **Smart Filtering**: Bookmark view shows only present/valid bookmarks
- **Color Consistency**: Bookmarks use same colors as in commit log (bold purple)

#### Implementation Details
- Navigation calculates correct line positions for each view type
- Highlighting system works transparently with both content types
- Bookmark objects include positioning metadata for seamless integration
- Status window shows current view type and appropriate counts

### Testing Considerations

- Tests require being run in a jj repository
- The test runner (`tests/run_tests.lua`) includes vim API mocks for standalone execution
- Tests validate command execution, parsing, commit structure, and rendering

## Vim Commands

- `:JJToggle` - Toggle the jj log window
- `:JJLog` - Open the jj log window
- `:JJClose` - Close the jj log window
- Default keymap: `<leader>ji` for toggle

## Dependencies

- Neovim with Lua support
- jj (jujutsu) CLI tool installed and available in PATH
- Must be run within a jj repository

## File Management

- Put all test files in the `tests/` directory for future use

## Design Conventions

- This project uses a structure where the default setting keybinds for actions are lowercase, while the advanced operations that use the menu system use the capital letter version.