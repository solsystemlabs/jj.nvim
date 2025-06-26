-- Test multi-parent commit creation functionality
-- Run with: lua tests/test_multi_parent.lua

package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Mock vim functions for standalone execution
if not vim then
  _G.vim = {
    split = function(str, sep, opts)
      local result = {}
      local pattern = string.format("([^%s]+)", sep)
      for match in str:gmatch(pattern) do
        table.insert(result, match)
      end
      return result
    end,
    fn = {
      strchars = function(str) return #str end,
      strcharpart = function(str, start, len) return str:sub(start + 1, start + len) end,
      input = function(prompt) 
        print(prompt)
        return "y"  -- Auto-confirm for testing
      end
    },
    log = {
      levels = { INFO = 2, WARN = 3, ERROR = 4 }
    },
    notify = function(msg, level)
      local level_name = "INFO"
      if level == 4 then level_name = "ERROR"
      elseif level == 3 then level_name = "WARN" end
      print(string.format("[%s] %s", level_name, msg))
    end,
    api = {
      nvim_set_hl = function() end,
      nvim_create_namespace = function() return 1 end
    }
  }
end

-- Create mock commit objects
local function create_mock_commit(short_id, change_id, description)
  return {
    short_change_id = short_id,
    change_id = change_id,
    get_short_description = function(self)
      return description or "Mock commit description"
    end,
    root = false,
    type = "commit"
  }
end

local function test_selection_column()
  print("=== Testing Selection Column Module ===")
  
  local selection_column = require('jj-nvim.ui.selection_column')
  
  -- Test 1: Column width
  local width = selection_column.get_selection_column_width()
  print(string.format("Column width: %d", width))
  assert(width == 2, "Column width should be 2")
  print("✓ Column width test passed")
  
  -- Test 2: Toggle selection
  local commit1 = create_mock_commit("abc12345", "abc123456789abcd", "First commit")
  local commit2 = create_mock_commit("def12345", "def123456789abcd", "Second commit")
  
  local selected = {}
  
  -- Add first commit
  selected = selection_column.toggle_commit_selection(commit1, selected)
  assert(#selected == 1, "Should have 1 selected commit")
  print("✓ Added first commit to selection")
  
  -- Add second commit
  selected = selection_column.toggle_commit_selection(commit2, selected)
  assert(#selected == 2, "Should have 2 selected commits")
  print("✓ Added second commit to selection")
  
  -- Remove first commit
  selected = selection_column.toggle_commit_selection(commit1, selected)
  assert(#selected == 1, "Should have 1 selected commit after removal")
  print("✓ Removed first commit from selection")
  
  -- Test 3: Validation
  local mixed_entries = { commit1, commit2 }
  local valid, error_msg, commit_objects = selection_column.validate_selection(selected, mixed_entries)
  assert(valid == false, "Should be invalid with only 1 commit")
  print("✓ Validation correctly rejects single commit")
  
  -- Add back first commit for valid selection
  selected = selection_column.toggle_commit_selection(commit1, selected)
  valid, error_msg, commit_objects = selection_column.validate_selection(selected, mixed_entries)
  assert(valid == true, "Should be valid with 2 commits")
  assert(#commit_objects == 2, "Should return 2 commit objects")
  print("✓ Validation correctly accepts multiple commits")
  
  -- Test 4: Selection summary
  local summary = selection_column.get_selection_summary(selected, mixed_entries)
  print(string.format("Selection summary: %s", summary))
  assert(string.find(summary, "2 commits"), "Summary should mention 2 commits")
  print("✓ Selection summary test passed")
  
  print("✓ All selection column tests passed!")
  return true
end

local function test_actions()
  print("\n=== Testing Actions Module ===")
  
  local actions = require('jj-nvim.jj.actions')
  
  -- Test 1: Function exists
  assert(actions.new_with_parents, "new_with_parents function should exist")
  print("✓ new_with_parents function exists")
  
  -- Test 2: Input validation
  local result = actions.new_with_parents(nil)
  assert(result == false, "Should return false for nil input")
  print("✓ Correctly rejects nil input")
  
  result = actions.new_with_parents({})
  assert(result == false, "Should return false for empty array")
  print("✓ Correctly rejects empty array")
  
  local commit1 = create_mock_commit("abc12345", "abc123456789abcd", "First commit")
  result = actions.new_with_parents({commit1})
  assert(result == false, "Should return false for single commit")
  print("✓ Correctly rejects single commit")
  
  -- Test 3: Description function
  local desc = actions.get_new_with_parents_description({})
  assert(string.find(desc, "No parent"), "Should mention no parents")
  print("✓ Description function works for empty selection")
  
  local commit2 = create_mock_commit("def12345", "def123456789abcd", "Second commit")
  desc = actions.get_new_with_parents_description({commit1, commit2})
  assert(string.find(desc, "2 parents"), "Should mention 2 parents")
  print("✓ Description function works for valid selection")
  
  print("✓ All actions tests passed!")
  return true
end

local function test_integration()
  print("\n=== Integration Test ===")
  
  local selection_column = require('jj-nvim.ui.selection_column')
  local actions = require('jj-nvim.jj.actions')
  
  -- Create mock commits
  local commit1 = create_mock_commit("abc12345", "abc123456789abcd", "First commit")
  local commit2 = create_mock_commit("def12345", "def123456789abcd", "Second commit")
  local commit3 = create_mock_commit("ghi12345", "ghi123456789abcd", "Third commit")
  
  local mixed_entries = { commit1, commit2, commit3 }
  
  -- Build selection
  local selected = {}
  selected = selection_column.toggle_commit_selection(commit1, selected)
  selected = selection_column.toggle_commit_selection(commit3, selected)
  
  -- Validate
  local valid, error_msg, commit_objects = selection_column.validate_selection(selected, mixed_entries)
  assert(valid == true, "Selection should be valid")
  assert(#commit_objects == 2, "Should have 2 commit objects")
  
  -- Test description generation
  local action_desc = actions.get_new_with_parents_description(commit_objects)
  print(string.format("Action description: %s", action_desc))
  
  local summary = selection_column.get_selection_summary(selected, mixed_entries)
  print(string.format("Selection summary: %s", summary))
  
  print("✓ Integration test passed!")
  return true
end

-- Run tests
local function run_all_tests()
  print("Running multi-parent commit creation tests...\n")
  
  local success = true
  success = success and test_selection_column()
  success = success and test_actions()
  success = success and test_integration()
  
  if success then
    print("\n🎉 ALL TESTS PASSED!")
    print("\nMulti-parent commit creation functionality is ready!")
    print("\nTo test in Neovim:")
    print("1. Open a jj repository")
    print("2. Run :JJToggle")
    print("3. Press 'n' to open new change menu")
    print("4. Press 'm' to enter multi-select mode")
    print("5. Use Space to select commits, Enter to confirm")
  else
    print("\n❌ Some tests failed")
  end
  
  return success
end

run_all_tests()