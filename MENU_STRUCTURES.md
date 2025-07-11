# Command Menu Structures

This document defines the menu structures for all commands that involve target selection or multi-commit operations. The goal is to create a consistent user experience where commands always show a menu first, giving users the choice between different selection methods.

## Design Principles

1. **Menu-First Approach**: All commands that require target selection should show a menu before entering selection mode
2. **Consistent Options**: All menus should offer both log selection and bookmark selection where applicable
3. **Clear Cancellation**: Users should always be able to cancel operations easily
4. **Discoverable Actions**: Menus should clearly explain what each option does

## Command Menu Structures

### Squash Command (`x` key)

**Current Behavior**: Immediately enters target selection mode
**New Behavior**: Show menu first with selection method options

**Step 1: Show Squash Menu (existing)**
```
┌─────────────────────────────────────┐
│ Squash @ into [target]              │
├─────────────────────────────────────┤
│ q │ Quick squash (standard)         │
│ i │ Interactive squash              │
│ m │ Use destination message & keep  │
│ c │ Cancel                          │
└─────────────────────────────────────┘
```

**Step 2: Show target selection menu**
```
┌─────────────────────────────────────┐
│ Squash @ - Select Target            │
├─────────────────────────────────────┤
│ l │ Select from log window          │
│ b │ Select from bookmarks           │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**: 
- Add `show_squash_target_selection_menu()` function
- Show existing squash options
- After squash option chosen, proceed to target selection menu (except for quick squash, which uses the parent)
- Maintain existing squash options (quick, interactive, keep emptied, custom message)

### Rebase Command (`r` key)

**Current Behavior**: Shows rebase options menu, some options trigger selection modes
**New Behavior**: Use submenus to separate operation type from target selection

**Step 1: Rebase Operation Type**
```
┌─────────────────────────────────────┐
│ Rebase @ - Choose Operation         │
├─────────────────────────────────────┤
│ b │ Rebase branch (-b)              │
│ s │ Rebase source (-s)              │
│ r │ Rebase specific commits (-r)    │
│ a │ Insert after target (-A)        │
│ f │ Insert before target (-B)       │
│ d │ Set destination (-d)            │
│ e │ Skip emptied commits (toggle)   │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Step 2: Target Selection Method (for operations requiring target)**
```
┌─────────────────────────────────────┐
│ Rebase @ - Select Target            │
├─────────────────────────────────────┤
│ l │ Select from log window          │
│ b │ Select from bookmarks           │
│ c │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Modify existing `show_rebase_options_menu()` to be operation-focused
- Add `show_rebase_target_selection_menu()` for target selection
- Keep existing multi-commit selection for revisions mode
- Handle skip-emptied as a toggle option that applies to next rebase

### Split Command (`s` key)

**Current Behavior**: Shows split options menu, some options trigger target selection
**New Behavior**: Use submenus to separate split type from target selection

**Step 1: Split Type**
```
┌─────────────────────────────────────┐
│ Split @ - Choose Method             │
├─────────────────────────────────────┤
│ i │ Interactive split (default)     │
│ p │ Parallel split                  │
│ f │ Split specific files            │
│ a │ Insert after target             │
│ b │ Insert before target            │
│ d │ Set destination                 │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Step 2: Target Selection Method (for operations requiring target)**
```
┌─────────────────────────────────────┐
│ Split @ - Select Target             │
├─────────────────────────────────────┤
│ l │ Select from log window          │
│ b │ Select from bookmarks           │
│ c │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Modify existing `show_split_options_menu()` to be split-type focused
- Add `show_split_target_selection_menu()` for target selection
- Direct execution for non-target operations (interactive, parallel, files)

### New Change Command (`N` key)

**Current Behavior**: Shows menu with options for after/before/merge, enters target selection for after/before
**New Behavior**: Use submenus to separate operation type from parent selection

**Step 1: New Change Type**
```
┌─────────────────────────────────────┐
│ Create New Change                   │
├─────────────────────────────────────┤
│ a │ Create after parent             │
│ b │ Create before parent            │
│ m │ Create merge commit             │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Step 2: Parent Selection Method (for after/before operations)**
```
┌─────────────────────────────────────┐
│ New Change - Select Parent          │
├─────────────────────────────────────┤
│ l │ Select from log window          │
│ b │ Select from bookmarks           │
│ c │ Cancel                          │
└─────────────────────────────────────┘
```

**Step 2b: Parent Selection Method (for merge operations)**
```
┌─────────────────────────────────────┐
│ Merge - Select Parents              │
├─────────────────────────────────────┤
│ l │ Select from log window          │
│ b │ Select from bookmarks           │
│ c │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Modify existing `show_new_change_menu()` to be operation-focused
- Add `show_new_change_parent_selection_menu()` for parent selection
- Add `show_merge_parent_selection_menu()` for merge parents
- Keep existing target selection and multi-select modes

### Abandon Command (`a`/`A` keys)

**Current Behavior**: Smart single/multi abandon based on existing selections
**New Behavior**: Keep `a` as smart abandon, use `A` for explicit multi-abandon with submenus

**`a` key behavior**: Keep current smart behavior (abandon current commit or selected commits)

**`A` key behavior**: Show multi-abandon menu

**Step 1: Multi-Abandon Type (A key only)**
```
┌─────────────────────────────────────┐
│ Abandon Multiple Commits            │
├─────────────────────────────────────┤
│ l │ Select from log window          │
│ b │ Select from bookmarks           │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Keep `a` key current behavior for simplicity
- Add `show_abandon_selection_menu()` for `A` key
- Provide both log and bookmark selection for multi-abandon

## Unified Selection System

### Design Goal

Instead of separate "log vs bookmark" submenus, use a unified selection interface where the log window can toggle between different views:
- **Log View**: Shows commit history (current behavior)
- **Bookmark View**: Shows bookmarks as selectable items in the same interface

### Unified Selection Flow

**Enter Selection Mode**:
1. Command triggers selection mode (target, multi-select, etc.)
2. Log window enters selection mode with visual indicators
3. User can toggle between log and bookmark views

**Selection Interface**:
- **j/k**: Navigate items (commits or bookmarks)
- **Space**: Toggle selection (for multi-select modes)
- **Enter**: Confirm selection and proceed
- **Esc**: Cancel selection mode
- **Ctrl+T**: Toggle between log view and bookmark view (in target/multi-select modes)
- **Tab**: Alternative toggle key (same functionality as Ctrl+T)

**Visual Indicators**:
- Status window shows current view: "View: log" or "View: bookmark"
- Status window shows counts: "2 commits selected" or "3 bookmarks (Selected: 1)"
- Unified highlighting for all content types (subtle gray cursor background)
- Bookmarks use same colors as in commit log (bold purple)
- Clear indication of current selection mode in status

### View Toggle Implementation

**Log View**: 
- Shows commit history with graph (current behavior)
- Selection works on commits
- Shows commit metadata (author, date, description)

**Bookmark View**:
- Shows bookmarks as a clean list in jj-native format
- Each bookmark shows: name, target change ID, status indicators
- Selection works on bookmarks (only present bookmarks shown)
- Format: `name@remote change_id (+tracking)` or `name change_id (conflict)`

### Mixed Selection Support

For merge commit creation:
1. User can select some commits from log view
2. Toggle to bookmark view with Ctrl+T
3. Select additional bookmarks
4. Status shows: "3 parents selected (2 commits, 1 bookmark)"
5. Confirm with Enter to create merge

### Simplified Menu Flows (with Unified Selection)

**Squash Flow**: `x` → Squash Options → Unified Selection (toggle log/bookmark with Ctrl+T) → Execute
**Rebase Flow**: `r` → Operation Type → (if target needed) Unified Selection → Execute  
**Split Flow**: `s` → Split Method → (if target needed) Unified Selection → Execute
**New Change Flow**: `N` → Change Type → Unified Selection (supports mixed selection for merge) → Execute
**Abandon Flow**: `A` → Unified Selection (multi-select mode) → Execute

### Updated Command Structures

Since we're eliminating the "log vs bookmark" submenus, the command structures become simpler:

**Squash Command (`x`)**:
1. Show squash options menu (quick, interactive, etc.)
2. If target needed, enter unified selection mode
3. Execute squash

**Rebase Command (`r`)**:
1. Show rebase operation menu (branch, source, revisions, etc.)
2. If target needed, enter unified selection mode
3. Execute rebase

**Split Command (`s`)**:
1. Show split method menu (interactive, parallel, insert after, etc.)
2. If target needed, enter unified selection mode  
3. Execute split

**New Change Command (`N`)**:
1. Show new change type menu (after, before, merge)
2. Enter unified selection mode (supports mixed selection for merge)
3. Execute new change

**Abandon Command (`A`)**:
1. Enter unified selection mode (multi-select)
2. Execute abandon

## Removed Functionality

### Standalone Selection Mode

**Removed**: Ability to select commits with Space key when not in a command flow
**Rationale**: Reduces cognitive load and prevents confusion about selection state
**Impact**: Users must explicitly start a command before selecting commits

**Files Affected**:
- `lua/jj-nvim/utils/keymaps.lua`: Remove Space key from main window
- `lua/jj-nvim/config.lua`: Remove `toggle_selection` from navigation section
- Keep selection logic only in special mode configurations

## Theme Integration

### Selection Highlight Colors

**Current Issue**: Hardcoded `#4a4a4a` gray doesn't match theme colors
**Solution**: Use theme-aware highlighting

**Files Affected**:
- `lua/jj-nvim/ui/multi_select.lua`: Replace hardcoded color with theme-based color
- `lua/jj-nvim/ui/themes.lua`: Add selection highlight definitions

## Implementation Status

**Status: ✅ COMPLETE** - Unified view toggle system fully implemented and tested.

### Key Features Implemented:
- **Unified Content Interface**: Both commits and bookmarks use the same properties (`line_start`, `line_end`, `content_type`)
- **Single Render Cycle**: Status and content updates happen atomically to prevent conflicts
- **View-Aware Navigation**: Proper line positioning for both log and bookmark views
- **Bookmark Styling**: jj-native format without emojis, proper coloring, filtered to show only present bookmarks
- **Seamless Integration**: All existing menus and workflows maintain compatibility

## Original Implementation Plan

### Phase 1: Foundation
1. **Create documentation** (✓ Complete)
2. **Fix selection highlight colors** (✓ Complete) - Theme-aware gray highlighting implemented
3. **Remove Space key from main window** (✓ Complete) - Standalone selection mode eliminated

### Phase 2: Unified Selection System (✓ Complete)
4. **Implement view toggle system** (✓ Complete):
   - Add `Ctrl+T`/`Tab` keybinds for view switching in selection mode
   - Create bookmark view renderer for log window
   - Add status indicators for current view and selection count
   - Handle mixed selection state (commits + bookmarks)

5. **Enhance selection modes** (✓ Complete):
   - Update target selection mode to support view toggling
   - Update multi-select mode to support view toggling
   - Add bookmark selection highlighting and navigation

### Phase 3: Menu Simplification (✓ Complete)
6. **Update command menus** (✓ Complete) - Squash menu enhanced to show options before selection

### Phase 4: Integration & Testing (✓ Complete)
7. **Test all command flows** (✓ Complete) - Unified selection system fully functional
8. **Update help and context systems** (✓ Complete) - Documentation updated
9. **Performance optimization** (✓ Complete) - Bookmark view rendering optimized

### Key Technical Challenges

1. **State Management**: Track selections across view switches
2. **Rendering**: Efficiently switch between log and bookmark display
3. **Mixed Selection**: Handle commit IDs vs bookmark names in selection state
4. **User Feedback**: Clear status and visual indicators for current mode
5. **Backward Compatibility**: Ensure existing selection logic still works
