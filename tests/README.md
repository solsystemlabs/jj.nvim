# JJ-NVIM Test Suite

This directory contains a comprehensive test suite for the jj-nvim plugin built with plenary.nvim.

## Overview

The test suite is organized into several categories:

- **Unit Tests**: Test individual modules and functions
- **Integration Tests**: Test component interactions and full workflows
- **Mock Utilities**: Provide controlled testing environments
- **Test Fixtures**: Sample data for testing

## Prerequisites

The test suite requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) to be installed:

### Using lazy.nvim
```lua
{ 'nvim-lua/plenary.nvim' }
```

### Using packer.nvim
```lua
use 'nvim-lua/plenary.nvim'
```

### Using vim-plug
```vim
Plug 'nvim-lua/plenary.nvim'
```

## Directory Structure

```
tests/
├── spec/                    # Test specifications
│   ├── core/               # Core module tests
│   │   ├── parser_spec.lua
│   │   └── renderer_spec.lua
│   ├── jj/                 # JJ command tests
│   │   └── commands_spec.lua
│   ├── ui/                 # UI component tests
│   │   ├── buffer_spec.lua
│   │   ├── window_spec.lua
│   │   └── navigation_spec.lua
│   └── integration/        # Integration tests
│       └── plugin_spec.lua
├── helpers/                # Test utilities
│   ├── mock_jj.lua        # JJ command mocking
│   └── test_utils.lua     # General test utilities
├── fixtures/              # Test data (future use)
├── run_tests.lua          # Main test runner
├── minimal_init.lua       # Minimal init for testing
└── README.md             # This file
```

## Running Tests

### From Neovim

```lua
-- Run all tests
:lua require('tests.run_tests')

-- Run specific test file
:PlenaryBustedFile tests/spec/core/parser_spec.lua

-- Run specific test directory
:PlenaryBustedDirectory tests/spec/core/
```

### From Command Line

```bash
# Run all tests
nvim --headless -c "lua require('tests.run_tests')" -c "quit"

# Run specific test file
nvim --headless -c "PlenaryBustedFile tests/spec/core/parser_spec.lua" -c "quit"
```

### With Make (if you create a Makefile)

```bash
make test
make test-unit
make test-integration
```

## Test Categories

### Core Module Tests

- **Parser Tests** (`spec/core/parser_spec.lua`)
  - Template parsing with field separators
  - Graph structure parsing
  - Commit data extraction
  - Error handling for malformed data
  - Integration between graph and template parsing

- **Renderer Tests** (`spec/core/renderer_spec.lua`)
  - Syntax highlighting generation
  - Multiple render modes (compact, comfortable, detailed)
  - Graph visualization preservation
  - Special commit type handling (working copy, empty, conflicts)
  - Bookmark rendering

### JJ Command Tests

- **Commands Tests** (`spec/jj/commands_spec.lua`)
  - Command execution with `vim.system`
  - Error handling and timeout scenarios
  - Notification management
  - String vs table argument handling
  - Real jj command integration

### UI Component Tests

- **Buffer Tests** (`spec/ui/buffer_spec.lua`)
  - Buffer creation from commit data
  - Buffer properties and options
  - Content rendering and highlighting
  - Keymap setup
  - State management

- **Window Tests** (`spec/ui/window_spec.lua`)
  - Window creation and management
  - Window positioning and sizing
  - Open/close state tracking
  - Integration with vim window system

- **Navigation Tests** (`spec/ui/navigation_spec.lua`)
  - Cursor movement between commits
  - Commit line identification
  - Multi-line commit handling
  - Boundary condition handling

### Integration Tests

- **Plugin Tests** (`spec/integration/plugin_spec.lua`)
  - Full plugin workflow testing
  - Component integration
  - Configuration handling
  - Error propagation
  - Real jj repository integration

## Mock Utilities

### Mock JJ Commands (`helpers/mock_jj.lua`)

Provides controlled testing environment for jj commands:

```lua
local mock_jj = require('tests.helpers.mock_jj')

-- Mock vim.system for jj commands
local mock_system = mock_jj.mock_vim_system({
  {
    code = 0,
    stdout = "mock output",
    stderr = ""
  }
})

-- Create mock commit objects
local mock_commits = mock_jj.create_mock_commits(5)

-- Restore original functions
mock_system.restore()
```

### Test Utilities (`helpers/test_utils.lua`)

General testing utilities:

```lua
local test_utils = require('tests.helpers.test_utils')

-- Assertions
test_utils.assert_contains(string, substring)
test_utils.assert_has_key(table, key)
test_utils.assert_length(table, expected_length)

-- Buffer/window management
local buf = test_utils.create_temp_buffer()
local win = test_utils.create_temp_window(buf)
test_utils.cleanup_buffer(buf)
test_utils.cleanup_window(win)

-- Skip tests when not in jj repo
test_utils.skip_if_not_jj_repo()
```

## Writing New Tests

### Test Structure

```lua
local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('module name', function()
  local module_under_test
  
  before_each(function()
    -- Reset module cache for clean state
    package.loaded['module.name'] = nil
    module_under_test = require('module.name')
    
    -- Set up mocks
  end)
  
  after_each(function()
    -- Clean up mocks and resources
  end)
  
  describe('function group', function()
    it('should do something', function()
      -- Test implementation
      assert.is_true(condition)
    end)
  end)
end)
```

### Best Practices

1. **Use descriptive test names**: Clearly describe what the test validates
2. **Clean up resources**: Always clean up buffers, windows, and mocks
3. **Mock external dependencies**: Use mock utilities for jj commands
4. **Test error conditions**: Include tests for failure scenarios
5. **Skip when appropriate**: Use `test_utils.skip_if_not_jj_repo()` for tests requiring jj
6. **Reset module cache**: Use `package.loaded[module] = nil` for clean state

### Common Patterns

```lua
-- Test with mock jj commands
local mock_system = mock_jj.mock_vim_system({
  { code = 0, stdout = "success" }
})
-- ... test code ...
mock_system.restore()

-- Test with mock commits
local mock_commits = mock_jj.create_mock_commits(3)
-- ... test code ...

-- Test with temporary buffer/window
local buf = test_utils.create_temp_buffer()
local win = test_utils.create_temp_window(buf)
-- ... test code ...
test_utils.cleanup_window(win)
test_utils.cleanup_buffer(buf)
```

## CI/CD Integration

The test suite can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run tests
  run: |
    nvim --headless -c "lua require('tests.run_tests')" -c "quit"
```

## Troubleshooting

### Common Issues

1. **Plenary not found**: Ensure plenary.nvim is installed and in runtimepath
2. **Module not found**: Check that the plugin is in runtimepath
3. **Tests hang**: Check for infinite loops or missing cleanup
4. **JJ command failures**: Verify you're in a jj repository for integration tests

### Debug Mode

For debugging tests, you can add print statements or use:

```lua
-- Debug test execution
vim.print(variable)
vim.inspect(table)
```

### Selective Test Running

```lua
-- Run only specific tests
:PlenaryBustedFile tests/spec/core/parser_spec.lua
```

## Contributing

When adding new features to jj-nvim:

1. Write tests for new functionality
2. Update existing tests if behavior changes
3. Add mock utilities for new external dependencies
4. Update this documentation for new test categories
5. Ensure tests pass before submitting PR

## Future Enhancements

- Add performance benchmarks
- Expand fixture data
- Add visual tests for UI components
- Integrate with coverage reporting
- Add property-based tests for edge cases