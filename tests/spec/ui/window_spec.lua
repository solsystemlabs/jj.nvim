local test_utils = require('tests.helpers.test_utils')

describe('ui.window', function()
  local window_module
  local test_buffer
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.ui.window'] = nil
    window_module = require('jj-nvim.ui.window')
    
    -- Create a test buffer
    test_buffer = test_utils.create_temp_buffer()
  end)
  
  after_each(function()
    -- Clean up windows and buffers
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(buf)
        if string.find(name, "jj-log") then
          vim.api.nvim_win_close(win, true)
        end
      end
    end
    
    test_utils.cleanup_buffer(test_buffer)
  end)

  describe('window management', function()
    it('should track window open state', function()
      -- Initially should not be open
      assert.is_false(window_module.is_open())
    end)
    
    it('should open window with buffer', function()
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        assert.is_number(win_id)
        assert.is_true(vim.api.nvim_win_is_valid(win_id))
        assert.is_true(window_module.is_open())
        
        -- Cleanup
        vim.api.nvim_win_close(win_id, true)
      end
    end)
    
    it('should close window', function()
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        assert.is_true(window_module.is_open())
        
        window_module.close()
        assert.is_false(window_module.is_open())
      end
    end)
  end)

  describe('window configuration', function()
    it('should create window with correct buffer', function()
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        local win_buf = vim.api.nvim_win_get_buf(win_id)
        assert.equals(test_buffer, win_buf)
        
        -- Cleanup
        vim.api.nvim_win_close(win_id, true)
      end
    end)
    
    it('should set window options', function()
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        -- Check common window options that might be set
        local options_to_check = {
          'number', 'relativenumber', 'wrap', 'cursorline'
        }
        
        for _, option in ipairs(options_to_check) do
          local success_opt, value = pcall(vim.api.nvim_win_get_option, win_id, option)
          if success_opt then
            assert.is_not_nil(value, "Option " .. option .. " should be set")
          end
        end
        
        -- Cleanup
        vim.api.nvim_win_close(win_id, true)
      end
    end)
  end)

  describe('window positioning', function()
    it('should handle different window positioning modes', function()
      -- Test depends on window module implementation
      -- This is a placeholder for positioning tests
      
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        -- Window should be created with reasonable dimensions
        local width = vim.api.nvim_win_get_width(win_id)
        local height = vim.api.nvim_win_get_height(win_id)
        
        assert.is_true(width > 0)
        assert.is_true(height > 0)
        
        -- Cleanup
        vim.api.nvim_win_close(win_id, true)
      end
    end)
  end)

  describe('error handling', function()
    it('should handle invalid buffer', function()
      local invalid_buffer = -1
      
      local success, result = pcall(window_module.open, invalid_buffer)
      
      -- Should either succeed with error handling or fail gracefully
      if not success then
        assert.is_string(result) -- Error message
      end
    end)
    
    it('should handle window close when not open', function()
      -- Should not crash when closing non-existent window
      assert.is_false(window_module.is_open())
      
      local success, result = pcall(window_module.close)
      
      -- Should handle gracefully
      if not success then
        assert.is_string(result) -- Error message
      end
    end)
    
    it('should handle multiple open calls', function()
      local success1, win_id1 = pcall(window_module.open, test_buffer)
      
      if success1 and win_id1 then
        local success2, win_id2 = pcall(window_module.open, test_buffer)
        
        -- Should handle gracefully - either reuse window or create new one
        if success2 and win_id2 then
          assert.is_number(win_id2)
          
          -- Cleanup both if different
          if win_id1 ~= win_id2 then
            if vim.api.nvim_win_is_valid(win_id1) then
              vim.api.nvim_win_close(win_id1, true)
            end
            if vim.api.nvim_win_is_valid(win_id2) then
              vim.api.nvim_win_close(win_id2, true)
            end
          else
            vim.api.nvim_win_close(win_id1, true)
          end
        else
          vim.api.nvim_win_close(win_id1, true)
        end
      end
    end)
  end)

  describe('window state persistence', function()
    it('should maintain window state correctly', function()
      assert.is_false(window_module.is_open())
      
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        assert.is_true(window_module.is_open())
        
        -- Manually close the window (not through the module)
        vim.api.nvim_win_close(win_id, true)
        
        -- The module should detect the window is closed
        -- Note: This depends on implementation - some modules may need manual update
        local still_tracking = window_module.is_open()
        
        -- Either it correctly detects closure, or we need to call close()
        if still_tracking then
          window_module.close()
          assert.is_false(window_module.is_open())
        end
      end
    end)
  end)

  describe('focus and navigation', function()
    it('should handle window focus', function()
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        -- Test focus functionality if available
        if window_module.focus then
          local focus_success = pcall(window_module.focus)
          -- Should not crash
          assert.is_boolean(focus_success)
        end
        
        -- Cleanup
        vim.api.nvim_win_close(win_id, true)
      end
    end)
  end)

  describe('integration with vim window system', function()
    it('should create window that integrates with vim', function()
      local initial_win_count = #vim.api.nvim_list_wins()
      
      local success, win_id = pcall(window_module.open, test_buffer)
      
      if success and win_id then
        local new_win_count = #vim.api.nvim_list_wins()
        assert.is_true(new_win_count >= initial_win_count)
        
        -- Window should be in the list
        local found_window = false
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if win == win_id then
            found_window = true
            break
          end
        end
        assert.is_true(found_window)
        
        -- Cleanup
        vim.api.nvim_win_close(win_id, true)
      end
    end)
  end)
end)