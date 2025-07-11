# Dynamic Flag Toggling System for jj-nvim Menu Enhancement

## Current Architecture Analysis

### Menu System Structure
The plugin has a sophisticated menu system with these key components:

1. **Action Menu** (`lua/jj-nvim/ui/action_menu.lua`): Context-aware menu showing actions based on selection state
2. **Inline Menu** (`lua/jj-nvim/ui/inline_menu.lua`): Core menu implementation with floating windows
3. **Command-specific Menus**: Specialized menus for operations like squash, rebase, split

### Command Execution Patterns
Commands follow a consistent pattern:
- **Simple execution**: Direct command building with flags
- **Options-based approach**: Commands accept option objects that map to CLI flags
- **Interactive vs non-interactive**: Commands can run in terminal or background
- **Immutable error handling**: Automatic retry prompts for immutable commit errors

### Current "Toggle-like" Implementations
The plugin already has several toggle patterns:
1. **View Toggle**: Switch between commit log and bookmark views
2. **Filter Toggle**: Cycle through bookmark filters (local → remote → all)
3. **Selection Toggle**: Multi-select mode for commits
4. **Description Toggle**: Expand/collapse commit descriptions

## Pain Points Identified

### Commands That Would Benefit from Dynamic Flag Toggling

1. **Git Push** (`jj git push`):
   - `--remote <remote>` (cycle through available remotes)
   - `--force-with-lease` (toggle force push)
   - `--allow-new` (toggle new bookmark creation)
   - `--branch <branch>` (select specific branch)

2. **Git Fetch** (`jj git fetch`):
   - `--remote <remote>` (cycle through available remotes)
   - `--branch <branch>` (select specific branch)

3. **Rebase** (`jj rebase`):
   - Source mode: `-b` (branch) ↔ `-s` (source) ↔ `-r` (revisions)
   - Destination: `-d` ↔ `-A` (after) ↔ `-B` (before)
   - `--skip-emptied` (toggle)
   - `--keep-divergent` (toggle)

4. **Split** (`jj split`):
   - `--interactive` (toggle)
   - `--parallel` (toggle)
   - Destination: `-d` ↔ `-A` ↔ `-B`

5. **Squash** (`jj squash`):
   - `--interactive` (toggle)
   - `--keep-emptied` (toggle)
   - `--use-destination-message` (toggle)

6. **New** (`jj new`):
   - Multiple parent support
   - Insert positioning options

## Implementation Plan

### Phase 1: Core Dynamic Menu Framework

1. **Create Dynamic Menu Component** (`lua/jj-nvim/ui/dynamic_menu.lua`):
   - Extend inline_menu with stateful flag tracking
   - Support for toggle flags, cycle flags, and input flags
   - Real-time menu regeneration on flag changes
   - Visual indicators for active flags

2. **Flag State Management**:
   - Per-command flag state storage
   - Persistence across menu sessions
   - Reset/clear functionality

3. **Menu Item Types**:
   - **Toggle Items**: Binary on/off flags (✓/✗ indicators)
   - **Cycle Items**: Multi-value flags (show current value)
   - **Input Items**: Prompt for values
   - **Action Items**: Execute with current flag state

### Phase 2: Enhanced Git Commands

1. **Dynamic Git Push Menu**:
   ```
   Git Push Options              [Current: jj git push --remote origin]
   
   r - Remote: origin ↺          [toggle through: origin, upstream, none]
   f - Force: ✗                  [toggle --force-with-lease]
   n - Allow new: ✗              [toggle --allow-new]
   b - Branch: <none>            [input prompt]
   ────────────────────────────
   Enter - Execute push
   Space - Preview command
   ```

2. **Dynamic Git Fetch Menu**:
   - Similar structure with fetch-specific options

### Phase 3: Enhanced Operation Commands

1. **Dynamic Rebase Menu**:
   ```
   Rebase Options               [Current: jj rebase -b abc123 -d main]
   
   s - Source mode: Branch ↺     [cycle: branch(-b) → source(-s) → revisions(-r)]
   d - Destination: main         [input prompt or target selection]
   t - Target type: Dest ↺       [cycle: dest(-d) → after(-A) → before(-B)]
   e - Skip emptied: ✗           [toggle --skip-emptied]
   k - Keep divergent: ✗         [toggle --keep-divergent]
   ────────────────────────────
   Enter - Execute rebase
   Space - Preview command
   ```

2. **Dynamic Split Menu**: Similar approach with split-specific flags
3. **Dynamic Squash Menu**: Enhanced version of current squash menu

### Phase 4: Advanced Features

1. **Command Preview**: Show full command before execution
2. **Flag Presets**: Save/load common flag combinations
3. **Smart Defaults**: Context-aware flag suggestions
4. **Flag Validation**: Prevent invalid flag combinations

### Implementation Strategy

1. **Backward Compatibility**: Keep existing simple menus as default
2. **Opt-in Enhancement**: Add config option to enable dynamic menus
3. **Progressive Enhancement**: Start with git commands, expand to others
4. **Consistent UX**: Follow existing toggle patterns and key conventions

### Key Benefits

1. **Reduced Context Switching**: No need to remember complex flag combinations
2. **Discoverability**: Users can see all available options at once
3. **Safety**: Preview commands before execution
4. **Efficiency**: Quick flag adjustments without menu navigation
5. **Learning**: Users learn command structure through interaction

This implementation would significantly enhance the user experience for complex jj operations while maintaining the plugin's current elegant simplicity for basic operations.