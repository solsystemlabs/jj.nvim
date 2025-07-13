# OpenCode.md

## Build, Lint, and Test Commands

- **Run all tests**: `lua tests/run_tests.lua`
- **Run specific tests**: Inside Neovim, use `:lua require('jj-nvim.tests.test_parser')`
- **Testing dynamic help integration**: `lua tests/spec/integration/dynamic_help_integration_spec.lua`
- **Lint**: Custom linting via consolidated error patterns (see CLAUDE.md).

## Code Style Guidelines

### Formatting
- Follow Lua conventions: Use 2-space indentation.
- Avoid trailing whitespace.

### Naming Conventions
- File names should use snake_case.
- Functions and variables should use camelCase.
- Constants should use UPPER_CASE.

### Imports
- Prefer explicit module paths: `require('jj-nvim.[module_path]')`.
- Group imports by scope: Standard libraries, jj-nvim utilities, external libraries.

### Types and Error Handling
- Use clear types and `nil` checks for critical functions.
- Wrap error-prone code with efficient error handling via `vim.errors`. 

### Testing
- Ensure new functionality includes coverage in `tests/spec`.
- Mock jj systems as needed for unit testing.

### Other Conventions
- Refactor repeated code where possible.
- Leverage command building utilities from `command_utils` (see ARCHITECTURE.md).