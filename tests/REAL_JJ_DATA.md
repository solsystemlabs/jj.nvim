# Real JJ Test Data Implementation

## Overview

The jj-nvim test suite now uses **real jj repository data** instead of hand-crafted mock strings. This provides much more robust and realistic testing.

## Architecture

### Components

1. **Test Repository** (`tests/fixtures/jj-log-testing/`)
   - Real jj repository with complex commit structure
   - Contains merges, branches, conflicts, bookmarks
   - Used as source for both fixture data and live testing

2. **Fixture Data** (`tests/fixtures/captured_data/`)
   - `graph_output.txt` - Real `jj log --template '"*" ++ commit_id.short(8)'` output
   - `template_output.txt` - Real `jj log --template COMMIT_TEMPLATE --no-graph` output
   - Captured from test repository for consistent fast testing

3. **Fixture Loader** (`tests/helpers/fixture_loader.lua`)
   - Loads real jj output data for tests
   - Automatically detects fixture availability
   - Provides fallback to simple mocks if fixtures unavailable

4. **Test Data Generator** (`tests/helpers/test_data_generator.lua`)
   - Regenerates fixture data from test repository
   - Validates fixture consistency
   - Supports different command options (limits, revsets)

5. **Enhanced Mock System** (`tests/helpers/mock_jj.lua`)
   - Uses real fixture data instead of hand-crafted strings
   - Provides live repository integration for complex testing
   - Maintains backward compatibility with existing tests

## Repository Structure

The test repository contains:

```
@  6d9fcea8 (working copy)
│ ×    14f3bcd1 (conflicts with multiple parents)
│ ├─╮
│ ○ │  ad08eb7a (feature branch changes)
│ │ │ ×    a514dc89 (more conflicts)
│ │ │ ├─╮
│ │ │ │ ○  0990bac6 (working commit)
│ ├─────╯
│ │ │ ○  a6d1b85b (main branch changes)
│ │ │ │ ×  4db589fc (empty commits, release bookmark)
│ │ ├───╯
│ │ × │  433f3673 (connector commits)
│ │ × │  91198aa2 (merge commits)
╭─┬─╯ │
○ │   │  c7b599a0 (parallel development)
├─────╯
○ │  743778a1 main (bookmarked)
│ ○  81b9cca5 feature (bookmarked)
│ ○  7ff583ff (linear history)
│ ○  217a330d 
│ ○  ddce5798
├─╯
│ ○  3654d4ca (test commits)
├─╯
○  a08df3c8 (root changes)
◆  00000000 (root commit)
```

This provides comprehensive test coverage for:
- Linear and branching history
- Merge commits with multiple parents
- Conflicts and resolutions
- Bookmarks (branches)
- Empty commits
- Working copy identification
- Complex graph structures

## Usage

### Running Tests with Real Data

Tests automatically use real fixture data when available:

```bash
# All existing tests now use real data
nvim --headless -c "PlenaryBustedFile tests/spec/core/parser_spec.lua" -c "quit"
```

### Live Repository Testing

For integration tests that need dynamic repository interaction:

```lua
-- In test files
local mock_jj = require('tests.helpers.mock_jj')

-- Use live repository (if available)
mock_system = mock_jj.mock_vim_system_with_test_repo()

-- Test will execute actual jj commands against test repository
local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 5 })
```

### Fixture Management

```lua
-- Check fixture availability
local fixture_loader = require('tests.helpers.fixture_loader')
if fixture_loader.fixtures_available() then
  print("Fixtures ready for testing")
end

-- Regenerate fixtures from repository
local test_data_generator = require('tests.helpers.test_data_generator')
test_data_generator.regenerate_fixtures()

-- Validate fixtures are current
local valid, message = test_data_generator.validate_fixtures()
print("Fixtures valid:", valid, message)
```

## Benefits

### 1. **Realistic Testing**
- Tests use actual jj output formats
- Automatically adapts to jj version changes
- Complex scenarios (merges, conflicts) are real

### 2. **Maintainable**
- No more hand-crafted mock strings
- Easy to add new test scenarios by creating commits
- Fixture validation ensures consistency

### 3. **Comprehensive Coverage**
- Complex branching patterns
- Multi-parent merges
- Conflict states
- Bookmark management
- Different commit types (empty, root, working copy)

### 4. **Future-Proof**
- Works with jj format evolution
- Easy to regenerate fixtures for new jj versions
- Supports different jj command options

## Test Categories

### 1. **Static Fixture Tests** (Fast)
- Use pre-captured real data
- Consistent results
- Fast execution
- Primary test method

### 2. **Live Repository Tests** (Comprehensive)
- Execute actual jj commands
- Dynamic repository state
- Integration testing
- Slower but thorough

### 3. **Fallback Mock Tests** (Compatibility)
- Simple mock data when fixtures unavailable
- Ensures tests work in any environment
- Backward compatibility

## Maintenance

### Updating Test Data

When the test repository structure needs changes:

1. Navigate to test repository:
   ```bash
   cd tests/fixtures/jj-log-testing
   ```

2. Make repository changes:
   ```bash
   jj new -m "New test scenario"
   echo "new content" > file.txt
   jj commit -m "Add new test case"
   ```

3. Regenerate fixtures:
   ```bash
   nvim --headless -c "lua require('tests.helpers.test_data_generator').regenerate_fixtures()" -c "quit"
   ```

### Validation

The test suite automatically warns if fixtures are out of sync:

```
Warning: Fixtures need updating: template data mismatch
Consider running: require('tests.helpers.test_data_generator').regenerate_fixtures()
```

## Migration Notes

- **Existing tests**: Continue to work unchanged
- **Mock data**: Now uses real fixture data automatically
- **Performance**: Fixture-based tests are still fast
- **Compatibility**: Fallbacks ensure tests work everywhere

This implementation provides the best of both worlds: realistic test data from real jj repositories, with the speed and reliability of fixture-based testing.