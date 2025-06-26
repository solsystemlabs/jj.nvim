# JJ-Nvim Plugin Development

## Project Overview

A Neovim plugin for interacting with the jujutsu (jj) version control system through an interactive log interface.

## Core Features Planned

- **Interactive Log Window**: Toggle sidebar showing `jj log` output
- **Navigation**: Vim-like keybinds for moving through commits
- **Commit Actions**: Edit, abandon, rebase commits directly from log
- **Diff Viewing**: Show commit diffs in split windows
- **Branch Management**: Create/switch branches from commits

## Advanced Features (Future)

- **Search/Filter**: Filter log by author, message, files
- **Visual Indicators**: Highlight current commit, conflicts
- **File Tree Integration**: Show changed files per commit
- **Bookmarks**: Quick access to bookmarked commits
- **Configuration**: Customizable keybinds, log format, colors

## Keybinds

### Global

- `<leader>jl`: Toggle jj log window

### Navigation & Display (in log window)

- `j/k`: Navigate commits (smart multi-line aware)
- `gg/G`: First/last commit
- `<CR>`: Show commit details/diff
- `dd`: Show diff for current commit (`jj diff`\)
- `s`: Show status (`jj status`\)
- `t`: Toggle log template
- `r`: Refresh log
- `q`: Close window

### Commit Operations

- `n`: New commit (`jj new`\)
- `e`: Edit current commit (`jj edit`\)
- `d`: Describe commit (`jj describe`\)
- `c`: Commit current changes (`jj commit`\)
- `a`: Abandon commit (`jj abandon`\)
- `D`: Duplicate commit (`jj duplicate`\)

### Bookmark Operations

- `b`: Create bookmark (`jj bookmark create`\)
- `bd`: Delete bookmark (`jj bookmark delete`\)
- `bl`: List bookmarks (`jj bookmark list`\)
- `bs`: Set bookmark (`jj bookmark set`\)
- `bm`: Move bookmark (`jj bookmark move`\)

### History Operations

- `R`: Rebase (`jj rebase`\)
- `S`: Squash (`jj squash`\)
- `sp`: Split commit (`jj split`\)
- `ab`: Absorb changes (`jj absorb`\)

### Git Operations

- `gf`: Git fetch (`jj git fetch`\)
- `gp`: Git push (`jj git push`\)
- `gc`: Git clone (`jj git clone`\)
- `gr`: Git remote (`jj git remote`\)

### Utility Operations

- `u`: Undo (`jj undo`\)
- `rv`: Revert (`jj revert`\)
- `rs`: Restore (`jj restore`\)
- `/`: Search/filter commits
- `?`: Help/show available keybinds

## Technical Architecture

```
lua/jj-nvim/
├── init.lua          # Main plugin entry
├── config.lua        # Configuration management
├── ui/
│   ├── window.lua    # Window management
│   ├── buffer.lua    # Buffer operations
│   └── highlight.lua # Syntax highlighting
├── jj/
│   ├── commands.lua  # JJ CLI wrapper
│   ├── log.lua       # Log parsing and display
│   └── actions.lua   # Commit actions
└── utils/
    ├── keymap.lua    # Keybind management
    └── helpers.lua   # Utility functions
```

## JJ Commands by Priority

### Priority 1: Essential Operations (MVP)

**Core Navigation & Viewing:**

- log, show, diff, status

**Commit Management:**

- new, edit, describe, commit, abandon, duplicate

**Bookmark Management:**

- bookmark (create, delete, list, set, move)

**Basic Operations:**

- undo, revert, restore

### Priority 2: Advanced Operations

**History Manipulation:**

- rebase, squash, split, absorb

**File Operations:**

- file, resolve, diffedit

**Navigation:**

- next, prev, root

**Advanced Viewing:**

- interdiff, evolog

### Priority 3: Specialized Features

**Git Integration:**

- git (clone, fetch, push, remote)

**Advanced Management:**

- operation, parallelize, simplify-parents

**Configuration:**

- config, workspace, sparse

**Signing & Tagging:**

- sign, unsign, tag

**Utilities:**

- util, help, version

## Core Architecture Requirements

- **Log Navigation**: Parse jj log output to create internal data structure for commit navigation
- **Graph Display**: Always show `jj log` with colors preserved
- **Multi-line Commits**: Navigate between commits regardless of template line count
- **Smart Terminal**: Auto-close floating terminals when commands complete, fallback to manual close
- **Single Instance**: One global jj log window per Neovim instance
- **Auto-refresh**: Update log after operations
- **Bookmark Integration**: Show bookmarks inline with commits in log view

## Development Progress

- [x] Plugin directory structure created
- [x] CLAUDE.md documentation started
- [x] Basic plugin initialization
- [x] Window management system
- [x] JJ log command execution
- [x] Toggle keybind implementation
- [x] Feature set and keybind scheme defined
- [x] Smart commit navigation (multi-line aware)
- [x] Color preservation in log output
- [x] Graph-aware line wrapping
- [x] Word-based description wrapping
- [x] Elided revision handling
- [x] Configurable window borders with theming
- [x] Basic commit operations (edit, abandon)
- [ ] Advanced new change system (see detailed plan below)
- [ ] Floating diff windows
- [ ] Bookmark management
- [ ] Auto-refresh system
- [ ] Status line integration

## Implementation Notes

- Target Neovim v0.11+
- Use lua for all logic
- Follow standard Neovim plugin conventions
- Handle jj not installed/repo not initialized gracefully
- Preserve jj's native colors in output
- Create internal data structure for commit navigation

---

# Advanced JJ New Change System - Comprehensive Implementation Plan

## Design Philosophy & Core Requirements

**Inspired by which-key plugin patterns:**
- Inline menu system that appears directly in the log window
- Configurable delay (immediate for now, extensible for future)
- Visual feedback with dummy commit injection
- Multi-selection workflows with dedicated UI elements
- Extensible foundation for other complex command operations

**Core User Workflows:**
1. **Simple new child** - Most common: `n` → `n` (or `Enter`) 
2. **Insert after/before** - Visual target selection with dummy commits
3. **Multi-parent commits** - Selection column with toggle workflow
4. **Bookmark integration** - Filtered view with bookmark selection
5. **Custom descriptions** - Inline message prompts

## Detailed Menu System Specifications

### Primary Menu Structure (triggered by 'n')
```
┌─ New Change Options ─────────────────────────────┐
│ Select commit to insert after, then press Enter │ <-- Instruction area
│ ─────────────────────────────────────────────── │ <-- Separator  
│ a  Insert after (select target commit)          │
│ b  Insert before (select target commit)         │
│ d  New child with description                    │
│ k  Select from bookmarks view                    │
│ m  New with multiple parents                     │
│ n  New child of current commit                   │
│                                                  │
│ <Enter> Execute default (n), <Esc> Cancel       │
└──────────────────────────────────────────────────┘
```

### Menu Behavior Rules
- **Positioning**: Uses same graph indentation as target commit
- **Always visible**: No delay, shows immediately on 'n' press
- **Alphabetical keybinds**: Sorted by letter (a, b, d, k, m, n)
- **Default action**: `Enter` executes 'n' (new child) - most common operation
- **Navigation**: `Esc` cancels, `Backspace` goes back one level in nested workflows
- **Instruction area**: Top section with distinct highlight, shows contextual guidance
- **Persistent during operations**: Hides/shows as appropriate for workflow

## Visual Design Specifications

### Selection Column System (for multi-select mode)
```
●  ○  abc123 user@email.com 2025-01-15 main
○  │  def456 user@email.com 2025-01-14  
○  │  ghi789 user@email.com 2025-01-13
^  ^
│  └─ Normal graph continues
└─ Selection column: 2 chars wide, light gray background
```

**Selection Column Details:**
- **Width**: Exactly 2 characters ("● " or "○ ")  
- **Position**: Before existing graph structure
- **Background**: Light gray background across entire column height
- **Indicators**: ○ (unselected), ● (selected) in orange/accent color
- **Interaction**: `Space` toggles selection, `Enter` confirms, `Esc` cancels
- **Persistence**: Visible only during multi-select mode, removed on completion/cancel

### Dummy Commit Injection (for target selection)
```
○  abc123 user@email.com 2025-01-15 feature-work
│  Add new feature implementation  
@  ── NEW COMMIT WILL BE INSERTED HERE ──  <-- Dummy commit
│  def456 user@email.com 2025-01-14 main
```

**Dummy Commit Details:**
- **Visual marker**: "@ NEW" or similar distinctive marker
- **Graph integration**: Proper graph structure showing final result
- **Movement**: Follows j/k navigation, updates position in real-time
- **Preview**: Shows exact final graph structure after commit creation
- **Highlight**: Special highlight group to distinguish from real commits

### Selected Commit Backgrounds
- **Multi-select**: Light orange/subtle background for selected commits
- **Target selection**: Highlight for commit being referenced
- **Menu context**: Same highlight as existing selected commit system

## State Management System

### Mode State Machine
```lua
local mode_states = {
  normal = {
    -- Standard log navigation, all normal keybinds active
    keymaps = { n = enter_new_menu, e = edit_commit, a = abandon_commit, ... }
  },
  
  new_menu = {
    -- Menu visible, letter keys route to specific actions
    keymaps = { 
      a = start_insert_after, b = start_insert_before, d = prompt_description,
      k = switch_bookmark_view, m = start_multi_select, n = new_child,
      ['<Enter>'] = new_child, ['<Esc>'] = exit_to_normal, ['<BS>'] = exit_to_normal
    },
    menu_visible = true,
    instruction = "Choose new change option"
  },
  
  selecting_target = {
    -- Dummy commit visible, j/k moves target position
    keymaps = {
      j = move_dummy_down, k = move_dummy_up, 
      ['<Enter>'] = confirm_target, ['<Esc>'] = exit_to_new_menu, ['<BS>'] = exit_to_new_menu
    },
    dummy_commit_visible = true,
    instruction = "Navigate to target position, press Enter to confirm"
  },
  
  multi_select = {
    -- Selection column visible, space toggles, enter confirms
    keymaps = {
      j = nav_down, k = nav_up, ['<Space>'] = toggle_selection,
      ['<Enter>'] = confirm_multi_select, ['<Esc>'] = exit_to_new_menu, ['<BS>'] = exit_to_new_menu
    },
    selection_column_visible = true,
    instruction = "Select parent commits with Space, Enter to confirm"
  },
  
  bookmark_view = {
    -- Filtered to bookmark commits only, normal navigation
    keymaps = { 
      j = nav_down, k = nav_up, ['<Enter>'] = select_bookmark,
      ['<Esc>'] = exit_to_new_menu, ['<BS>'] = exit_to_new_menu,
      ['<C-b>'] = toggle_bookmark_view -- Global toggle still works
    },
    bookmark_filter_active = true,
    instruction = "Navigate to bookmark, press Enter to select"
  }
}
```

### State Transition Rules
```
normal → new_menu (n key)
new_menu → selecting_target (a/b keys)  
new_menu → multi_select (m key)
new_menu → bookmark_view (k key)
new_menu → normal (execute action like n, d)
selecting_target → new_menu (Backspace)
multi_select → new_menu (Backspace)  
bookmark_view → new_menu (Backspace)
Any state → normal (Esc from top level, or after action completion)
```

## Technical Architecture

### Core Module Structure
```lua
-- ui/inline_menu.lua - Menu system foundation
show_menu(win_id, line_number, menu_config)
hide_menu(win_id) 
update_menu_instruction(win_id, instruction_text)
create_menu_config(items, instruction, highlight_groups)

-- ui/dummy_commits.lua - Target selection system  
inject_dummy_commit(commits, position, commit_type)
move_dummy_commit(commits, current_pos, direction)
remove_dummy_commits(commits)
calculate_insertion_point(commits, target_commit, operation_type)

-- ui/selection_column.lua - Multi-select system
render_selection_column(commits, selected_change_ids)
toggle_commit_selection(change_id, selected_list)
get_selection_column_width()
highlight_selected_commits(win_id, selected_commits)

-- jj/bookmarks.lua - Bookmark integration
parse_bookmarks() -- Uses 'jj bookmark list' with template
filter_commits_by_bookmarks(commits, bookmarks)
get_bookmark_for_commit(commit, bookmarks)
```

### Enhanced Renderer Pipeline
```lua
-- Current: commits → rendered_lines
-- Enhanced: commits → [apply_filters] → [inject_dummies] → [add_selection_column] → [add_menu] → rendered_lines

function enhanced_render_pipeline(commits, mode_state, window_width)
  local working_commits = commits
  
  -- 1. Apply bookmark filter if in bookmark view
  if mode_state.bookmark_filter_active then
    working_commits = filter_commits_by_bookmarks(working_commits, get_bookmarks())
  end
  
  -- 2. Inject dummy commits if in target selection mode
  if mode_state.dummy_commit_visible then
    working_commits = inject_dummy_commit(working_commits, mode_state.dummy_position, mode_state.operation_type)
  end
  
  -- 3. Render with selection column if in multi-select mode
  local column_data = nil
  if mode_state.selection_column_visible then
    column_data = {
      selected_commits = mode_state.selected_commits,
      column_width = get_selection_column_width()
    }
  end
  
  -- 4. Standard rendering with enhancements
  local rendered_lines = render_commits_with_enhancements(working_commits, column_data, window_width)
  
  -- 5. Add inline menu if visible
  if mode_state.menu_visible then
    rendered_lines = add_inline_menu(rendered_lines, mode_state.menu_line, mode_state.menu_config)
  end
  
  return rendered_lines
end
```

### Action Function Extensions
```lua
-- In jj/actions.lua, extend with comprehensive new change operations

-- Basic operations
new_child(commit, message?)
new_with_message(commit, message)

-- Target-based operations  
new_after(target_commit, reference_commit, message?)
new_before(target_commit, reference_commit, message?)

-- Multi-parent operations
new_with_parents(parent_commits, message?)
new_merge_from_selection(selected_change_ids, message?)

-- Bookmark operations
new_from_bookmark(bookmark_name, message?)
new_child_of_bookmark(bookmark_name, message?)

-- Validation helpers
can_insert_after(commit) -- false for last commit without children
can_insert_before(commit) -- false for root commit
validate_parents(parent_commits) -- check for cycles, etc.
```

## Implementation Phases

### Phase 1: Core Menu Infrastructure ⭐ START HERE
**Goal**: Basic inline menu system with keybind routing

**Tasks**:
1. Create `ui/inline_menu.lua` with basic show/hide functionality
2. Add mode state management to `window.lua`
3. Implement menu positioning using commit graph indentation  
4. Add basic keybind routing for menu items
5. Create menu configuration structure
6. Test basic `n` → menu → `n` → new child workflow

**Acceptance Criteria**:
- `n` key shows inline menu under current commit
- Menu shows alphabetically sorted options
- `Enter` executes default action (new child)
- `Esc` cancels and returns to normal mode
- Menu uses proper graph indentation

### Phase 2: Simple New Child Operation
**Goal**: Complete the most common workflow

**Tasks**:
1. Extend `actions.lua` with `new_child()` function
2. Implement `jj new <change_id>` command execution
3. Add buffer refresh after successful operations
4. Add proper error handling and user feedback
5. Test end-to-end workflow

**Acceptance Criteria**:
- `n` → `n` creates new child of current commit
- `n` → `Enter` creates new child of current commit  
- Buffer refreshes to show new state
- Proper error messages for failures
- Works with all commit types (except root validation)

### Phase 3: Dummy Commit Target Selection
**Goal**: Visual target selection for insert after/before

**Tasks**:
1. Create `ui/dummy_commits.lua` module
2. Implement dummy commit injection into commit list
3. Add dummy commit movement with j/k navigation
4. Implement real-time graph preview calculation
5. Create target selection mode with instruction display
6. Implement `new_after()` and `new_before()` actions
7. Add visual highlighting for dummy commits

**Acceptance Criteria**:
- `n` → `a` shows dummy commit at insertion point
- j/k moves dummy commit position with graph updates
- `Enter` confirms and creates commit at dummy location
- `Backspace` returns to menu, `Esc` cancels completely
- Graph accurately previews final structure

### Phase 4: Multi-Selection System
**Goal**: Selection column for multi-parent commits

**Tasks**:
1. Create `ui/selection_column.lua` module
2. Implement 2-character selection column rendering
3. Add selection state management and persistence
4. Implement `Space` toggle and visual feedback
5. Create `new_with_parents()` action for multi-parent commits
6. Add background highlighting for selected commits
7. Test complex multi-parent scenarios

**Acceptance Criteria**:
- `n` → `m` shows selection column with all commits
- `Space` toggles commit selection with visual feedback
- Selected commits get subtle background highlight
- `Enter` creates merge commit with selected parents
- Selection column disappears after completion/cancel

### Phase 5: Bookmark Integration
**Goal**: Bookmark parser and filtered view system

**Tasks**:
1. Create `jj/bookmarks.lua` parser module
2. Implement `jj bookmark list` command with template
3. Create bookmark data structure and caching
4. Implement commit filtering by bookmark presence
5. Add global `<C-b>` keybind for bookmark view toggle
6. Integrate bookmark selection into new change workflow
7. Add bookmark type differentiation (local/remote/deleted)

**Acceptance Criteria**:
- `<C-b>` toggles between normal and bookmark-only views
- Bookmark view shows only commits with bookmarks
- `n` → `k` switches to bookmark view with selection
- Navigation works identically in bookmark view
- Bookmark data accurately parsed from jj output

### Phase 6: Advanced Features & Polish
**Goal**: Description prompts, validation, edge cases

**Tasks**:
1. Implement inline description prompting
2. Add comprehensive validation for all operations
3. Handle edge cases (root commits, conflicts, etc.)
4. Add configuration options for all behaviors
5. Implement proper error recovery
6. Add visual polish and animations
7. Performance optimization for large repositories

**Acceptance Criteria**:
- `n` → `d` prompts for description inline
- All operations validate inputs before execution
- Graceful handling of invalid operations
- Configurable keybinds and visual elements
- Smooth performance with 1000+ commits

## Configuration Structure

### Keybind Configuration
```lua
new_change = {
  trigger = 'n',                    -- Main trigger key
  keymaps = {
    insert_after = 'a',
    insert_before = 'b', 
    description = 'd',
    bookmarks = 'k',
    multiple_parents = 'm',
    new_child = 'n',
    confirm = '<Enter>',
    cancel = '<Esc>',
    back = '<BS>'
  }
}

bookmark_view = {
  toggle = '<C-b>'                  -- Global bookmark view toggle
}
```

### Visual Configuration
```lua
visual = {
  menu = {
    highlight_group = 'JJMenuSelected',
    instruction_highlight = 'JJMenuInstruction',
    border_chars = { '─', '│', '┌', '┐', '└', '┘' }
  },
  
  selection_column = {
    width = 2,
    background = 'light_gray',
    unselected_char = '○',
    selected_char = '●',
    selected_highlight = 'JJSelectedCommit'
  },
  
  dummy_commits = {
    marker_text = '── NEW COMMIT ──',
    highlight_group = 'JJDummyCommit'
  }
}
```

### Behavior Configuration  
```lua
behavior = {
  auto_refresh = true,              -- Refresh buffer after operations
  confirm_destructive = true,       -- Confirm operations like abandon
  show_operation_feedback = true,   -- Show success/error messages
  preserve_cursor_position = true   -- Return cursor to same commit after operations
}
```

## Future Extensibility Framework

### Menu System Reusability
The inline menu system is designed to support other complex operations:

```lua
-- Future: Rebase menu
rebase_menu = {
  trigger = 'r',
  items = {
    { key = 'a', desc = 'Rebase after target', action = rebase_after },
    { key = 'b', desc = 'Rebase before target', action = rebase_before },
    { key = 'o', desc = 'Rebase onto target', action = rebase_onto }
  }
}

-- Future: Squash menu  
squash_menu = {
  trigger = 's',
  items = {
    { key = 'i', desc = 'Squash into parent', action = squash_into },
    { key = 's', desc = 'Squash selection', action = squash_selection }
  }
}
```

### Visual Selection Patterns
The selection column and dummy commit systems can be reused:

- **Rebase operations**: Dummy commits showing rebase target
- **Squash operations**: Multi-select for squashing multiple commits
- **File operations**: Selection for file-specific operations
- **Bookmark operations**: Target selection for bookmark placement

### State Management Patterns
The mode state system provides a template for other complex workflows:

- **Interactive rebase**: Step-by-step rebase with visual feedback
- **Conflict resolution**: Guided conflict resolution workflow
- **File staging**: Interactive file selection and staging
- **History exploration**: Time-travel with visual indicators

## Success Metrics & Validation

### Performance Requirements
- **Menu response time**: < 50ms from keypress to menu display
- **Dummy commit updates**: < 100ms for position changes
- **Large repository support**: Smooth operation with 1000+ commits
- **Memory usage**: < 50MB additional overhead for features

### User Experience Requirements  
- **Discoverability**: New users can understand options without documentation
- **Efficiency**: Expert users can execute common operations in < 3 keystrokes
- **Visual clarity**: All operations provide clear visual feedback
- **Error recovery**: Users can always escape from any workflow state

### Integration Requirements
- **Buffer integration**: No conflicts with existing log window features
- **Theming compatibility**: Works with all existing theme configurations
- **Configuration compatibility**: Integrates with existing keybind customization
- **Future extensibility**: Framework supports adding new commands without refactoring

---

*This plan serves as the definitive reference for implementing the advanced JJ new change system. Update this document as implementation progresses and requirements evolve.*

