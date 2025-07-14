-- Test that commands use cursor commit instead of hardcoded @
local command_flow = require('jj-nvim.ui.command_flow')

local function test_cursor_commit_capture()
  -- Mock navigation.get_current_commit to return a test commit
  package.loaded['jj-nvim.ui.navigation'] = {
    get_current_commit = function(win_id)
      return {
        change_id = "test_change_123",
        commit_id = "commit_abc456"
      }
    end
  }
  
  -- Test that start_flow captures cursor commit
  local success = command_flow.start_flow("squash", 1)
  
  if not success then
    print("FAIL: start_flow failed")
    return false
  end
  
  if command_flow.state.cursor_commit ~= "test_change_123" then
    print("FAIL: cursor_commit not captured correctly. Expected: test_change_123, Got: " .. tostring(command_flow.state.cursor_commit))
    return false
  end
  
  print("PASS: cursor commit captured correctly")
  
  -- Clean up
  command_flow.close()
  
  return true
end

local function test_cursor_commit_fallback()
  -- Mock navigation.get_current_commit to return nil
  package.loaded['jj-nvim.ui.navigation'] = {
    get_current_commit = function(win_id)
      return nil
    end
  }
  
  -- Test that start_flow handles missing cursor commit
  local success = command_flow.start_flow("squash", 1)
  
  if not success then
    print("FAIL: start_flow failed")
    return false
  end
  
  if command_flow.state.cursor_commit ~= nil then
    print("FAIL: cursor_commit should be nil when no commit under cursor. Got: " .. tostring(command_flow.state.cursor_commit))
    return false
  end
  
  print("PASS: cursor commit fallback works correctly")
  
  -- Clean up
  command_flow.close()
  
  return true
end

-- Run tests
print("Testing cursor commit operations...")
local test1_passed = test_cursor_commit_capture()
local test2_passed = test_cursor_commit_fallback()

if test1_passed and test2_passed then
  print("All tests passed!")
  return true
else
  print("Some tests failed!")
  return false
end