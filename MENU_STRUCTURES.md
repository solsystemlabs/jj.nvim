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

**Step 1: Target Selection Method**
```
┌─────────────────────────────────────┐
│ Squash @ - Select Target            │
├─────────────────────────────────────┤
│ l │ Select from log window          │
│ b │ Select from bookmarks           │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Step 2: After target selected, show squash options menu (existing)**
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

**Implementation**: 
- Add `show_squash_target_selection_menu()` function
- After target selection method chosen, proceed to existing squash options menu
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

## Selection Mode Flows

### General Menu Navigation

All menus follow consistent navigation patterns:
- **j/k or ↑/↓**: Navigate menu items
- **Enter**: Select current item
- **Esc or q**: Cancel/go back to previous menu
- **Backspace**: Go back to parent menu (where applicable)

### Log Window Selection Flow

When "Select from log window" is chosen:
1. Enter target selection mode with visual indicators
2. User navigates with j/k, confirms with Enter, cancels with Esc
3. Return to next step in command flow after target selected

### Bookmark Selection Flow

When "Select from bookmarks" is chosen:
1. Show bookmark list in floating menu
2. User selects bookmark with j/k navigation
3. Confirm selection and proceed to next step in command flow
4. No additional target selection needed

### Multi-Commit Selection Flow

For commands that support multiple commits (merge parents, multi-abandon):
1. Enter multi-select mode with visual indicators
2. User toggles commits with Space, confirms with Enter, cancels with Esc
3. Show selected commit count in status
4. Proceed to command execution after confirmation

### Menu Flow Examples

**Squash Flow**: `x` → Target Selection Method → Log/Bookmark Selection → Squash Options → Execute
**Rebase Flow**: `r` → Operation Type → Target Selection Method → Log/Bookmark Selection → Execute
**Split Flow**: `s` → Split Method → (If target needed) Target Selection Method → Log/Bookmark Selection → Execute
**New Change Flow**: `N` → Change Type → Parent Selection Method → Log/Bookmark Selection → Execute

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

## Implementation Order

1. Create this documentation
2. Fix selection highlight colors
3. Remove Space key from main window
4. Implement menu-first squash command
5. Enhance rebase and split menus with bookmark options
6. Test all command flows
7. Update CLAUDE.md to reference this document
