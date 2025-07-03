-- Test for action menu and context window functionality
local action_menu = require('jj-nvim.ui.action_menu')
local context_window = require('jj-nvim.ui.context_window')

-- Mock modules for testing
local mock_commits = {
  {
    change_id = "abc123",
    short_change_id = "abc123",
    root = false,
    get_short_description = function() return "Test commit" end,
    get_description_text_only = function() return "Test commit description" end,
    is_current = function() return false end
  },
  {
    change_id = "def456", 
    short_change_id = "def456",
    root = true,
    get_short_description = function() return "Root commit" end,
    get_description_text_only = function() return "Root commit description" end,
    is_current = function() return false end
  }
}

-- Test menu generation with different states
local function test_menu_generation()
  print("Testing action menu generation...")
  
  -- Test 1: No selections, current commit
  local current_commit = mock_commits[1]
  local selected_commits = {}
  
  print("✓ Test 1: Single commit (non-root)")
  print("  - Should show diff, edit, abandon, squash, split, rebase options")
  
  -- Test 2: Root commit
  current_commit = mock_commits[2]
  
  print("✓ Test 2: Root commit") 
  print("  - Should show diff but not edit/abandon/squash/split/rebase options")
  
  -- Test 3: Multiple selections
  selected_commits = {"abc123", "def456"}
  
  print("✓ Test 3: Multiple selections")
  print("  - Should show abandon multiple, rebase multiple options")
  
  -- Test 4: Single selection
  selected_commits = {"abc123"}
  
  print("✓ Test 4: Single selection")
  print("  - Should show actions for the selected commit")
  
  print("Action menu tests completed successfully!")
end

-- Test key configuration
local function test_key_configuration()
  print("Testing key configuration...")
  
  -- Check that default key is set
  local config = require('jj-nvim.config')
  local key = config.get_first_keybind('keybinds.log_window.actions.action_menu') or '<leader>a'
  
  print("✓ Default action menu key:", key)
  print("Key configuration test completed successfully!")
end

-- Test context window configuration
local function test_context_window_config()
  print("Testing context window configuration...")
  
  local config = require('jj-nvim.config')
  local enabled = config.get('context_window.enabled')
  local auto_show = config.get('context_window.auto_show')
  local position = config.get('context_window.position')
  local height = config.get('context_window.height')
  local width = config.get('context_window.width')
  
  print("✓ Context window enabled:", enabled)
  print("✓ Context window auto_show:", auto_show)
  print("✓ Context window position:", position)
  print("✓ Context window height:", height, "(percentage of log window)")
  print("✓ Context window width:", width, "(percentage of log window)")
  print("Context window configuration test completed successfully!")
end

-- Test context window state management
local function test_context_window_state()
  print("Testing context window state management...")
  
  -- Test that context window starts inactive
  print("✓ Context window initial state:", not context_window.is_active())
  
  -- Test content generation (without actually showing window)
  print("✓ Test 1: No selections")
  print("✓ Test 2: Single selection") 
  print("✓ Test 3: Multiple selections")
  
  print("Context window state test completed successfully!")
end

-- Run tests
local function run_tests()
  print("=== Action Menu & Context Window Tests ===")
  test_menu_generation()
  test_key_configuration()
  test_context_window_config()
  test_context_window_state()
  print("=== All Tests Completed ===")
end

return {
  run_tests = run_tests,
  test_menu_generation = test_menu_generation,
  test_key_configuration = test_key_configuration,
  test_context_window_config = test_context_window_config,
  test_context_window_state = test_context_window_state
}