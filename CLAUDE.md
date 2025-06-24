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
- [ ] Smart commit navigation (multi-line aware)
- [ ] Color preservation in log output
- [ ] Floating diff windows
- [ ] Basic commit operations (new, edit, describe)
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

