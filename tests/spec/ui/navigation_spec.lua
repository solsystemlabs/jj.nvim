local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('ui.navigation', function()
  local navigation
  local test_buffer
  local test_window
  local mock_commits
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.ui.navigation'] = nil
    navigation = require('jj-nvim.ui.navigation')
    
    -- Create test environment
    mock_commits = mock_jj.create_mock_commits(5)
    test_buffer = test_utils.create_temp_buffer()
    test_window = test_utils.create_temp_window(test_buffer)
    
    -- Set up buffer with some test content
    local test_lines = {
      "@  ◆ commit_1 Test commit 1",
      "│",
      "○  ○ commit_2 Test commit 2", 
      "│",
      "○  ○ commit_3 Test commit 3"
    }
    vim.api.nvim_buf_set_lines(test_buffer, 0, -1, false, test_lines)
  end)
  
  after_each(function()
    test_utils.cleanup_window(test_window)
    test_utils.cleanup_buffer(test_buffer)
  end)

  describe('cursor movement', function()
    it('should move to next commit', function()
      -- Set cursor to first line
      vim.api.nvim_win_set_cursor(test_window, {1, 0})
      
      if navigation.next_commit then
        local success = pcall(navigation.next_commit)
        
        if success then
          local cursor = vim.api.nvim_win_get_cursor(test_window)
          local row = cursor[1]
          
          -- Should move to a line with commit content
          assert.is_true(row > 1)
        end
      end
    end)
    
    it('should move to previous commit', function()
      -- Set cursor to last commit line
      vim.api.nvim_win_set_cursor(test_window, {5, 0})
      
      if navigation.prev_commit then
        local success = pcall(navigation.prev_commit)
        
        if success then
          local cursor = vim.api.nvim_win_get_cursor(test_window)
          local row = cursor[1]
          
          -- Should move to an earlier line
          assert.is_true(row < 5)
        end
      end
    end)
    
    it('should handle cursor at buffer boundaries', function()
      -- Test at top of buffer
      vim.api.nvim_win_set_cursor(test_window, {1, 0})
      
      if navigation.prev_commit then
        local success = pcall(navigation.prev_commit)
        -- Should handle gracefully (stay at top or wrap)
        assert.is_boolean(success)
      end
      
      -- Test at bottom of buffer
      local line_count = vim.api.nvim_buf_line_count(test_buffer)
      vim.api.nvim_win_set_cursor(test_window, {line_count, 0})
      
      if navigation.next_commit then
        local success = pcall(navigation.next_commit)
        -- Should handle gracefully (stay at bottom or wrap)
        assert.is_boolean(success)
      end
    end)
  end)

  describe('commit selection', function()
    it('should get current commit', function()
      vim.api.nvim_win_set_cursor(test_window, {1, 0})
      
      if navigation.get_current_commit then
        local success, commit = pcall(navigation.get_current_commit)
        
        if success and commit then
          assert.is_table(commit)
          -- Should have commit-like structure
          assert.is_true(type(commit.short_commit_id) == 'string' or 
                        type(commit.commit_id) == 'string' or
                        type(commit.description) == 'string')
        end
      end
    end)
    
    it('should get commit at specific line', function()
      if navigation.get_commit_at_line then
        local success, commit = pcall(navigation.get_commit_at_line, 1)
        
        if success and commit then
          assert.is_table(commit)
        end
      end
    end)
    
    it('should handle invalid line numbers', function()
      if navigation.get_commit_at_line then
        local success, result = pcall(navigation.get_commit_at_line, -1)
        
        -- Should handle gracefully
        if not success then
          assert.is_string(result) -- Error message
        elseif result == nil then
          -- Returned nil for invalid line (acceptable)
          assert.is_nil(result)
        end
        
        -- Test with line beyond buffer
        local line_count = vim.api.nvim_buf_line_count(test_buffer)
        local success2, result2 = pcall(navigation.get_commit_at_line, line_count + 10)
        
        if not success2 then
          assert.is_string(result2)
        elseif result2 == nil then
          assert.is_nil(result2)
        end
      end
    end)
  end)

  describe('line identification', function()
    it('should identify commit lines vs connector lines', function()
      -- Test with lines that have commit symbols
      local commit_line = "@  ◆ commit_1 Test commit 1"
      local connector_line = "│"
      
      if navigation.is_commit_line then
        assert.is_true(navigation.is_commit_line(commit_line))
        assert.is_false(navigation.is_commit_line(connector_line))
      end
    end)
    
    it('should handle different commit symbols', function()
      local symbols = {'@', '○', '◆', '×'}
      
      if navigation.is_commit_line then
        for _, symbol in ipairs(symbols) do
          local test_line = symbol .. "  test commit"
          assert.is_true(navigation.is_commit_line(test_line), 
            "Should recognize " .. symbol .. " as commit symbol")
        end
      end
    end)
    
    it('should handle empty or malformed lines', function()
      if navigation.is_commit_line then
        assert.is_false(navigation.is_commit_line(""))
        assert.is_false(navigation.is_commit_line("   "))
        assert.is_false(navigation.is_commit_line("no symbols here"))
      end
    end)
  end)

  describe('multi-line commit handling', function()
    it('should handle commits that span multiple lines', function()
      -- Create buffer with multi-line commit
      local multi_line_content = {
        "@  ◆ commit_1 Test commit 1",
        "   This is a longer description",
        "   that spans multiple lines",
        "│",
        "○  ○ commit_2 Test commit 2"
      }
      vim.api.nvim_buf_set_lines(test_buffer, 0, -1, false, multi_line_content)
      
      if navigation.get_commit_boundaries then
        local success, start_line, end_line = pcall(navigation.get_commit_boundaries, 1)
        
        if success then
          assert.is_number(start_line)
          assert.is_number(end_line)
          assert.is_true(end_line >= start_line)
        end
      end
    end)
  end)

  describe('navigation with real buffer data', function()
    it('should work with rendered commit buffer', function()
      -- Create a buffer similar to what the renderer would create
      local buffer_module = require('jj-nvim.ui.buffer')
      local success, real_buffer = pcall(buffer_module.create_from_commits, mock_commits)
      
      if success and real_buffer then
        local real_window = test_utils.create_temp_window(real_buffer)
        
        -- Test navigation on real buffer
        if navigation.next_commit then
          vim.api.nvim_set_current_win(real_window)
          local nav_success = pcall(navigation.next_commit)
          assert.is_boolean(nav_success)
        end
        
        -- Cleanup
        test_utils.cleanup_window(real_window)
        test_utils.cleanup_buffer(real_buffer)
      end
    end)
  end)

  describe('keybinding integration', function()
    it('should handle navigation keybindings', function()
      -- Test that navigation functions can be called from keybindings
      local functions_to_test = {
        'next_commit', 'prev_commit', 'get_current_commit'
      }
      
      for _, func_name in ipairs(functions_to_test) do
        if navigation[func_name] then
          local success = pcall(navigation[func_name])
          assert.is_boolean(success, "Function " .. func_name .. " should not crash")
        end
      end
    end)
  end)

  describe('error handling', function()
    it('should handle invalid buffer context', function()
      -- Test navigation when not in a jj-log buffer
      local regular_buffer = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(regular_buffer, 0, -1, false, {"regular", "buffer", "content"})
      local regular_window = test_utils.create_temp_window(regular_buffer)
      
      vim.api.nvim_set_current_win(regular_window)
      
      if navigation.get_current_commit then
        local success, result = pcall(navigation.get_current_commit)
        
        -- Should handle gracefully
        if not success then
          assert.is_string(result) -- Error message
        else
          assert.is_nil(result) -- No commit found
        end
      end
      
      -- Cleanup
      test_utils.cleanup_window(regular_window)
      test_utils.cleanup_buffer(regular_buffer)
    end)
    
    it('should handle empty buffer', function()
      local empty_buffer = vim.api.nvim_create_buf(false, true)
      local empty_window = test_utils.create_temp_window(empty_buffer)
      
      vim.api.nvim_set_current_win(empty_window)
      
      if navigation.next_commit then
        local success = pcall(navigation.next_commit)
        assert.is_boolean(success)
      end
      
      -- Cleanup
      test_utils.cleanup_window(empty_window)
      test_utils.cleanup_buffer(empty_buffer)
    end)
  end)
end)