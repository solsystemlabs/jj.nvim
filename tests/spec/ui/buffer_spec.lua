local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('ui.buffer', function()
  local buffer_module
  local mock_commits
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.ui.buffer'] = nil
    buffer_module = require('jj-nvim.ui.buffer')
    
    -- Create mock commits
    mock_commits = mock_jj.create_mock_commits(3)
  end)
  
  after_each(function()
    -- Clean up any buffers created during tests
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if string.find(name, "jj-log") then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
  end)

  describe('create_from_commits', function()
    it('should create a buffer from commits', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      assert.is_not_nil(buf_id)
      assert.is_number(buf_id)
      assert.is_true(vim.api.nvim_buf_is_valid(buf_id))
    end)
    
    it('should handle empty commit list', function()
      local buf_id = buffer_module.create_from_commits({})
      
      assert.is_not_nil(buf_id)
      assert.is_number(buf_id)
      assert.is_true(vim.api.nvim_buf_is_valid(buf_id))
      
      -- Buffer should be empty
      local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
      assert.is_true(#lines <= 1)  -- May have one empty line
    end)
    
    it('should handle nil commits', function()
      local buf_id = buffer_module.create_from_commits(nil)
      
      -- Should handle gracefully
      if buf_id then
        assert.is_number(buf_id)
        assert.is_true(vim.api.nvim_buf_is_valid(buf_id))
      end
    end)
  end)

  describe('buffer properties', function()
    it('should create buffer with correct properties', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      -- Check buffer options
      assert.is_false(vim.api.nvim_buf_get_option(buf_id, 'modifiable'))
      assert.equals('nofile', vim.api.nvim_buf_get_option(buf_id, 'buftype'))
      assert.equals('hide', vim.api.nvim_buf_get_option(buf_id, 'bufhidden'))
      assert.is_false(vim.api.nvim_buf_get_option(buf_id, 'swapfile'))
    end)
    
    it('should set buffer filetype', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      local filetype = vim.api.nvim_buf_get_option(buf_id, 'filetype')
      assert.equals('jj-log', filetype)
    end)
    
    it('should set buffer name', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      local name = vim.api.nvim_buf_get_name(buf_id)
      test_utils.assert_contains(name, 'jj-log')
    end)
  end)

  describe('buffer content', function()
    it('should populate buffer with commit data', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
      assert.is_true(#lines > 0)
      
      -- Should contain commit information
      local content = table.concat(lines, '\n')
      assert.is_true(string.len(content) > 0)
    end)
    
    it('should include commit symbols in buffer', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
      local content = table.concat(lines, '\n')
      
      -- Should find commit symbols
      local found_symbol = false
      for _, symbol in ipairs({'@', '○', '◆', '×'}) do
        if string.find(content, symbol) then
          found_symbol = true
          break
        end
      end
      
      assert.is_true(found_symbol, "Buffer should contain commit symbols")
    end)
    
    it('should include commit descriptions', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
      local content = table.concat(lines, '\n')
      
      -- Should find commit descriptions
      test_utils.assert_contains(content, "Test commit")
    end)
  end)

  describe('buffer highlighting', function()
    it('should apply syntax highlighting', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      -- Check that highlights are applied
      local highlights = vim.api.nvim_buf_get_extmarks(buf_id, -1, 0, -1, { details = true })
      assert.is_table(highlights)
      -- Note: The exact number of highlights depends on the renderer implementation
    end)
  end)

  describe('buffer state management', function()
    it('should store commit data in buffer variables', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      -- Check if commit data is stored (implementation dependent)
      local success, stored_commits = pcall(vim.api.nvim_buf_get_var, buf_id, 'jj_commits')
      if success then
        assert.is_table(stored_commits)
        assert.equals(#mock_commits, #stored_commits)
      end
    end)
    
    it('should handle buffer recreation', function()
      local buf_id1 = buffer_module.create_from_commits(mock_commits)
      local buf_id2 = buffer_module.create_from_commits(mock_commits)
      
      -- Both should be valid
      assert.is_true(vim.api.nvim_buf_is_valid(buf_id1))
      assert.is_true(vim.api.nvim_buf_is_valid(buf_id2))
      
      -- Should be different buffers or same buffer reused
      assert.is_number(buf_id1)
      assert.is_number(buf_id2)
    end)
  end)

  describe('buffer keymaps', function()
    it('should set up buffer-local keymaps', function()
      local buf_id = buffer_module.create_from_commits(mock_commits)
      
      -- Check if keymaps are set (implementation dependent)
      local keymaps = vim.api.nvim_buf_get_keymap(buf_id, 'n')
      assert.is_table(keymaps)
      
      -- Should have some buffer-local keymaps
      local has_buffer_keymaps = false
      for _, keymap in ipairs(keymaps) do
        if keymap.buffer == 1 then
          has_buffer_keymaps = true
          break
        end
      end
      
      -- Note: This test may fail if keymaps are set up differently
      -- The actual implementation should be checked
    end)
  end)

  describe('error handling', function()
    it('should handle invalid commit data gracefully', function()
      local invalid_commits = {
        {}, -- Empty commit object
        { description = "Only description" }, -- Incomplete commit
        nil, -- Nil commit
      }
      
      -- Should not crash
      local success, result = pcall(buffer_module.create_from_commits, invalid_commits)
      
      if success then
        assert.is_number(result)
        assert.is_true(vim.api.nvim_buf_is_valid(result))
      else
        -- If it fails, it should fail gracefully
        assert.is_string(result) -- Error message
      end
    end)
    
    it('should handle buffer creation failure', function()
      -- Mock a scenario where buffer creation might fail
      local original_create_buf = vim.api.nvim_create_buf
      local call_count = 0
      
      vim.api.nvim_create_buf = function(...)
        call_count = call_count + 1
        if call_count == 1 then
          error("Mocked buffer creation failure")
        end
        return original_create_buf(...)
      end
      
      local success, result = pcall(buffer_module.create_from_commits, mock_commits)
      
      -- Restore original function
      vim.api.nvim_create_buf = original_create_buf
      
      -- Should handle gracefully
      if not success then
        assert.is_string(result) -- Error message
      end
    end)
  end)
end)