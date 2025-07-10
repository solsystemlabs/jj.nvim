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

```
┌─────────────────────────────────────┐
│ Squash @ into target                │
├─────────────────────────────────────┤
│ ↵ │ Select target from log window   │
│ b │ Select target from bookmarks    │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**: 
- Add `show_squash_target_menu()` function
- After target selection method chosen, proceed to existing squash options menu
- Maintain existing squash options (quick, interactive, keep emptied, custom message)

### Rebase Command (`r` key)

**Current Behavior**: Shows rebase options menu, some options trigger selection modes
**New Behavior**: Enhanced menu with clear bookmark selection options

```
┌─────────────────────────────────────┐
│ Rebase @ options                    │
├─────────────────────────────────────┤
│ b │ Rebase branch to log target     │
│ B │ Rebase branch to bookmark       │
│ s │ Rebase source to log target     │
│ S │ Rebase source to bookmark       │
│ r │ Rebase multiple commits         │
│ a │ Insert after log target         │
│ A │ Insert after bookmark           │
│ f │ Insert before log target        │
│ F │ Insert before bookmark          │
│ e │ Skip emptied commits            │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Modify existing `show_rebase_options_menu()` to include bookmark variants
- Add bookmark selection flows for each rebase mode
- Keep existing multi-commit selection for revisions mode

### Split Command (`s` key)

**Current Behavior**: Shows split options menu, some options trigger target selection
**New Behavior**: Enhanced menu with bookmark selection options

```
┌─────────────────────────────────────┐
│ Split @ options                     │
├─────────────────────────────────────┤
│ i │ Interactive split (default)     │
│ p │ Parallel split                  │
│ f │ Split specific files            │
│ a │ Insert after log target         │
│ A │ Insert after bookmark           │
│ b │ Insert before log target        │
│ B │ Insert before bookmark          │
│ d │ Set destination from log        │
│ D │ Set destination from bookmark   │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Modify existing `show_split_options_menu()` to include bookmark variants
- Add bookmark selection flows for destination/insert operations

### New Change Command (`N` key)

**Current Behavior**: Shows menu with options for after/before/merge, enters target selection for after/before
**New Behavior**: Enhanced menu with bookmark selection options

```
┌─────────────────────────────────────┐
│ Create New Change                   │
├─────────────────────────────────────┤
│ a │ Create after log target         │
│ A │ Create after bookmark           │
│ b │ Create before log target        │
│ B │ Create before bookmark          │
│ m │ Create merge (select parents)   │
│ M │ Create merge from bookmarks     │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Modify existing `show_new_change_menu()` to include bookmark variants
- Add bookmark selection flows for after/before operations
- Add bookmark multi-select for merge commit creation
- Keep existing target selection and multi-select modes

### Abandon Command (`a`/`A` keys)

**Current Behavior**: Smart single/multi abandon based on existing selections
**New Behavior**: Keep current smart behavior, document menu structure for consistency

```
┌─────────────────────────────────────┐
│ Abandon commit(s)                   │
├─────────────────────────────────────┤
│ ↵ │ Abandon current commit          │
│ m │ Select multiple from log        │
│ b │ Select multiple from bookmarks  │
│ q │ Cancel                          │
└─────────────────────────────────────┘
```

**Implementation**:
- Current behavior already works well for single commits
- Add optional menu for multi-abandon operations
- Consider showing this menu when `A` is pressed (explicit multi-abandon)

## Selection Mode Flows

### Log Window Selection Flow

When "Select from log window" is chosen:
1. Enter target selection mode with visual indicators
2. User navigates with j/k, confirms with Enter, cancels with Esc
3. Show bookmark option (`b` key) during target selection
4. Return to command-specific options menu after target selected

### Bookmark Selection Flow

When "Select from bookmarks" is chosen:
1. Show bookmark list in floating menu
2. User selects bookmark with j/k navigation
3. Confirm selection and proceed to command execution
4. No additional target selection needed

### Multi-Commit Selection Flow

For commands that support multiple commits:
1. Enter multi-select mode with visual indicators
2. User toggles commits with Space, confirms with Enter, cancels with Esc
3. Show selected commit count in status
4. Proceed to command execution after confirmation

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
