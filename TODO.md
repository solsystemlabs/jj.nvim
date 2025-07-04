# JJ-Nvim Feature Roadmap

## High Priority Features

### File-Level Diff Navigation
- Navigate between changed files within a diff view
- Jump to specific files from diff summary
- File tree view for commits with many changes
- Quick file filtering and search within diffs

### Search & Filter Capabilities
- Search commits by message, author, or date range
- Filter by branch, bookmark, or tag
- Quick search with fuzzy matching
- Saved search patterns and filters

## Medium Priority Features

### Performance Optimization
- Lazy loading for large repositories
- Incremental log updates and caching
- Background refresh with smart invalidation
- Optimized rendering for large commit graphs

### Integration Features
- LSP integration for commit message editing
- Telescope.nvim integration for search
- Which-key.nvim integration for keybindings
- FZF integration for fuzzy commit selection

### Advanced Theming
- Custom highlight groups and color schemes
- Theme-aware graph rendering
- Configurable commit status indicators
- Support for popular colorscheme plugins

## Low Priority Features

### Contextual Actions
- File-specific operations from diff view
- Blame integration for individual files
- Cherry-pick operations with conflict handling
- Patch creation and application

### Workspaces & Bookmarks
- Bookmark frequently accessed commits
- Workspace-specific configurations
- Quick navigation between bookmarks
- Persistent workspace state

## Infrastructure Improvements

### Testing & Quality
- Comprehensive test suite expansion
- Integration tests with real repositories
- Performance benchmarking
- Documentation improvements

### Developer Experience
- Plugin development guides
- Configuration examples
- Migration guides for version updates
- API documentation for extensibility

## Misc 
- Add support for rebase/new/etc commands based off of bookmarks instead of selected commits


## Completed Features ✓

- Multi-commit selection and operations
- Diff viewing with multiple formats
- Floating window support for diffs
- Graph-aware text wrapping research
- Conflict indicator display
- In-window status display
- Comprehensive refactoring and code cleanup