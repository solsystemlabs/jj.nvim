# Sequential Command Flow with Flag Toggle Menu

## Desired Command Flow

Every complex command should follow this sequential pattern:

1. **Command Keystroke** - User presses command key (e.g., `r` for rebase)
2. **Target/Option Menu** - Shows non-flag options (targets, modes, etc.)
3. **Selection Step** - If needed, prompt user to select targets
4. **Flag Toggle Menu** - Final step to toggle command flags before execution
5. **Command Execution** - Execute the fully configured command

## Menu Types

### Unified Menu
For commands that don't require target selection (like git push), combine targets and flags in a single menu to avoid unnecessary steps.

### Sequential Menu  
For commands that require interactive target selection (like rebase destination), use the full 5-step flow.

## Example Flows

### Git Push Flow (Unified Menu)

- Note: Use 'jj git remote list' to get the list of configured remotes. Generate a menu item for each item in the list.

  ```
  Step 1: User presses 'P' (git push)
  Step 2: Git Push Unified Menu       [Current: jj git push --remote origin]
  
  Targets:
  r - Push to remote 'origin'
  u - Push to remote 'upstream'  
  a - Push to all remotes
  ────────────────────────────
  Flags:
  f - Force with lease: ✗     [toggle --force-with-lease]
  n - Allow new: ✗            [toggle --allow-new]
  b - Specific branch: ✗      [toggle + input branch name]
  ────────────────────────────
  Enter - Execute push

  Step 3: Execute: jj git push --remote origin
  ```

### Git Fetch Flow (Unified Menu)

  ```
  Step 1: User presses 'F' (git fetch)
  Step 2: Git Fetch Unified Menu      [Current: jj git fetch --remote origin]
  
  Targets:
  r - Fetch from remote 'origin'
  u - Fetch from remote 'upstream'
  a - Fetch from all remotes
  ────────────────────────────
  Flags:
  b - Specific branch: ✗      [toggle + input branch name]
  ────────────────────────────
  Enter - Execute fetch

  Step 3: Execute: jj git fetch --remote origin
  ```

### Rebase Flow

```
Step 1: User presses 'r' (rebase)
Step 2: Rebase Source Menu
        b - Rebase branch (current selection)
        s - Rebase source commits
        r - Rebase specific revisions

Step 3: [Selection step - choose destination commit/bookmark]

Step 4: Rebase Flags Menu           [Current: jj rebase -b abc123 -d main]
        e - Skip emptied: ✗         [toggle --skip-emptied]
        k - Keep divergent: ✗       [toggle --keep-divergent]
        i - Interactive: ✗          [toggle --interactive]
        ────────────────────────────
        Enter - Execute rebase

Step 5: Execute: jj rebase -b abc123 -d main
```

### Squash Flow

```
Step 1: User presses 's' (squash)
Step 2: Squash Target Menu
        p - Squash into parent
        i - Choose destination

Step 3: [Selection step if needed - choose destination]

Step 4: Squash Flags Menu           [Current: jj squash -i]
        k - Keep emptied: ✗         [toggle --keep-emptied]
        m - Use dest message: ✗     [toggle --use-destination-message]
        r - Interactive mode: ✓     [toggle --interactive]
        ────────────────────────────
        Enter - Execute squash

Step 5: Execute: jj squash -i --interactive
```

## Implementation Architecture

### Core Components

1. **Command Flow Manager** (`lua/jj-nvim/ui/command_flow.lua`\):
   - Orchestrates the sequential menu flow
   - Manages state between steps
   - Handles step transitions and cancellation

2. **Flag Toggle Menu** (`lua/jj-nvim/ui/flag_menu.lua`\):
   - Generic flag toggling interface
   - Per-command flag definitions
   - Visual flag state indicators
   - Command preview generation

3. **Enhanced Command Definitions**:
   - Separate target/option menus from flag menus
   - Flag metadata (type, default, description)
   - Step-by-step flow definitions

### Menu Flow State Management

```lua
CommandFlowState = {
  command = "rebase",           -- Command being built
  step = 3,                     -- Current step (1-5)
  base_options = {              -- Non-flag options from steps 1-3
    source_type = "branch",
    destination = "main"
  },
  flags = {                     -- Flag state from step 4
    skip_emptied = false,
    keep_divergent = true,
    interactive = false
  },
  command_preview = "jj rebase -b abc123 -d main --keep-divergent"
}
```

### Flag Menu Features

1. **Visual Indicators**:
   - `✓` for enabled flags
   - `✗` for disabled flags
   - `↺` for cycle flags showing current value
   - Live command preview at top

2. **Flag Types**:
   - **Toggle**: Binary on/off (most flags)
   - **Cycle**: Multiple values (e.g., source type: branch → source → revisions)
   - **Input**: Prompt for string value (e.g., branch name, message)

3. **Smart Defaults**:
   - Context-aware flag suggestions
   - Remember previous flag combinations per command
   - Validate flag combinations and disable invalid options

### Implementation Strategy

1. **Incremental Rollout**: Start with one command (git push) as proof of concept
2. **Backward Compatibility**: Keep simple commands as single-step when no flags needed
3. **Consistent Keybinds**: Use same flag keys across commands where possible
4. **Escape Hatch**: Allow quick execution with defaults (bypass flag menu)

### Key Benefits

1. **Predictable Flow**: Every complex command follows same pattern
2. **Separation of Concerns**: Targets/options separate from flags
3. **Discoverability**: Users learn available flags through interaction
4. **Safety**: Always preview final command before execution
5. **Flexibility**: Can toggle multiple flags without menu navigation

### Commands Requiring This Flow

**High Priority**:

- Git push/fetch (multiple remotes, force options)
- Rebase (source types, positioning, behavior flags)
- Split (interactive, parallel, positioning)

**Medium Priority**:

- Squash (interactive, message handling, emptied commits)
- New (multiple parents, positioning)
- Abandon (recursive, interactive confirmation)

**Low Priority**:

- Edit (interactive vs direct)
- Describe (interactive vs message input)

