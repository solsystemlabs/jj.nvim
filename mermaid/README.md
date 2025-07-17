# JJ-Nvim Command Workflows - Mermaid Diagrams

This directory contains comprehensive mermaid diagrams documenting all command workflows in the jj-nvim plugin.

## Available Diagrams

### Core Operations
- **[rebase.md](rebase.md)** - Rebase command with all menu options (branch, source, revisions, destinations)
- **[abandon.md](abandon.md)** - Abandon commits with multi-select support and validation
- **[edit.md](edit.md)** - Edit commit to change working directory
- **[squash.md](squash.md)** - Squash commits with interactive options
- **[split.md](split.md)** - Split commits with various methods (interactive, parallel, fileset)
- **[duplicate.md](duplicate.md)** - Duplicate commits with destination options

### Change Creation
- **[new.md](new.md)** - Create new changes (child, after, before, merge, simple)
- **[diff.md](diff.md)** - Show commit diffs in multiple formats
- **[describe.md](describe.md)** - Set commit descriptions with interactive input

### Repository Operations
- **[git.md](git.md)** - Git operations (fetch, push) with smart error handling
- **[bookmark.md](bookmark.md)** - Bookmark management and view toggling
- **[status.md](status.md)** - Repository status display
- **[undo.md](undo.md)** - Undo operations with operation history
- **[commit.md](commit.md)** - Commit working copy changes

### User Interface
- **[action_menu.md](action_menu.md)** - Action menu system and context window

## Diagram Features

Each diagram includes:
- **Complete execution flows** from user action to command completion
- **Menu options** and interactive elements
- **Error handling** and validation paths
- **Success feedback** and UI updates
- **File locations** and keybindings
- **Command variations** and flags

## Usage

These diagrams can be viewed on:
- **[Mermaid Live Editor](https://mermaid.live/)** - Copy/paste the mermaid code
- **GitHub/GitLab** - Native mermaid rendering in markdown
- **VS Code** - With mermaid preview extensions
- **Documentation sites** - Most support mermaid rendering

## Architecture Overview

The jj-nvim plugin uses a layered architecture:

1. **User Interface Layer** - Menus, windows, navigation
2. **Actions Layer** - Command orchestration and validation
3. **Commands Layer** - JJ CLI command execution
4. **Core Layer** - Parsing, rendering, data management

Each workflow diagram shows the complete flow through these layers, from user interaction to final result display.

## Key Patterns

Common patterns across all workflows:
- **Validation** - Input and state validation before execution
- **Menu Systems** - Consistent interactive menu interfaces
- **Error Handling** - Graceful error handling with user feedback
- **Progress Feedback** - Visual indicators for long operations
- **UI Updates** - Automatic refresh and state synchronization

## Contributing

When adding new commands or modifying existing ones:
1. Update the relevant mermaid diagram
2. Test the diagram on mermaid.live
3. Document any new menu options or flows
4. Update this README if adding new diagrams