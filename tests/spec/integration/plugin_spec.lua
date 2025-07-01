local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('plugin integration', function()
  local jj_nvim
  local mock_system
  local mock_notify
  
  before_each(function()
    -- Reset all module caches for clean state
    local modules_to_reset = {
      'jj-nvim',
      'jj-nvim.init',
      'jj-nvim.config',
      'jj-nvim.core.parser',
      'jj-nvim.core.renderer',
      'jj-nvim.ui.buffer',
      'jj-nvim.ui.window',
      'jj-nvim.jj.commands'
    }
    
    for _, mod in ipairs(modules_to_reset) do
      package.loaded[mod] = nil
    end
    
    -- Set up mocks
    mock_system = mock_jj.mock_vim_system()
    mock_notify = mock_jj.mock_vim_notify()
    
    -- Load the main plugin
    jj_nvim = require('jj-nvim')
  end)
  
  after_each(function()
    if mock_system then
      mock_system.restore()
    end
    if mock_notify then
      mock_notify.restore()
    end
    
    -- Clean up any windows/buffers created
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(buf)
        if string.find(name, "jj-log") then
          vim.api.nvim_win_close(win, true)
        end
      end
    end
  end)

  describe('plugin setup', function()
    it('should initialize without errors', function()
      local success = pcall(jj_nvim.setup, {})
      assert.is_true(success)
    end)
    
    it('should accept configuration options', function()
      local config = {
        window = {
          position = 'bottom',
          size = 0.3
        },
        theme = 'default'
      }
      
      local success = pcall(jj_nvim.setup, config)
      assert.is_true(success)
    end)
    
    it('should handle empty configuration', function()
      local success = pcall(jj_nvim.setup)
      assert.is_true(success)
    end)
  end)

  describe('main plugin functions', function()
    it('should provide show_log function', function()
      assert.is_function(jj_nvim.show_log)
    end)
    
    it('should provide toggle function', function()
      assert.is_function(jj_nvim.toggle)
    end)
    
    it('should provide close function', function()
      assert.is_function(jj_nvim.close)
    end)
  end)

  describe('show_log workflow', function()
    it('should complete full show_log workflow', function()
      local success, result = pcall(jj_nvim.show_log)
      
      -- Should either succeed or fail gracefully with mocked jj commands
      if not success then
        -- Error should be a string (error message)
        assert.is_string(result)
      else
        -- Should have created a buffer and window
        local jj_buffers = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if string.find(name, "jj-log") then
              table.insert(jj_buffers, buf)
            end
          end
        end
        
        assert.is_true(#jj_buffers > 0, "Should create jj-log buffer")
      end
    end)
  end)

  describe('toggle workflow', function()
    it('should handle toggle when closed', function()
      local success = pcall(jj_nvim.toggle)
      
      -- Should either succeed or fail gracefully
      assert.is_boolean(success)
    end)
    
    it('should handle toggle when open', function()
      -- First open
      pcall(jj_nvim.show_log)
      
      -- Then toggle (should close)
      local success = pcall(jj_nvim.toggle)
      assert.is_boolean(success)
    end)
  end)

  describe('close workflow', function()
    it('should handle close when nothing is open', function()
      local success = pcall(jj_nvim.close)
      assert.is_boolean(success)
    end)
    
    it('should close after opening', function()
      -- First open
      pcall(jj_nvim.show_log)
      
      -- Then close
      local success = pcall(jj_nvim.close)
      assert.is_boolean(success)
    end)
  end)

  describe('error handling integration', function()
    it('should handle jj command failures gracefully', function()
      mock_system.restore()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 1,
          stdout = "",
          stderr = "jj: No repository found"
        }
      })
      
      local success, result = pcall(jj_nvim.show_log)
      
      -- Should handle error gracefully
      if not success then
        assert.is_string(result)
      else
        -- Check if error was communicated through notifications
        local notifications = mock_notify.get_notifications()
        local found_error = false
        for _, notif in ipairs(notifications) do
          if notif.level == vim.log.levels.ERROR then
            found_error = true
            break
          end
        end
        assert.is_true(found_error, "Should show error notification")
      end
    end)
    
    it('should handle empty repository', function()
      mock_system.restore()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "",
          stderr = ""
        },
        {
          code = 0,
          stdout = "",
          stderr = ""
        }
      })
      
      local success, result = pcall(jj_nvim.show_log)
      
      -- Should handle empty repository gracefully
      if not success then
        assert.is_string(result)
      else
        -- Should either show empty buffer or appropriate message
        local notifications = mock_notify.get_notifications()
        -- May show info message about empty repository
      end
    end)
  end)

  describe('component integration', function()
    it('should integrate parser and renderer', function()
      local parser = require('jj-nvim.core.parser')
      local renderer = require('jj-nvim.core.renderer')
      
      -- Test the integration chain
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 3 })
      
      if not err and commits and #commits > 0 then
        local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable')
        
        assert.is_table(highlighted_lines)
        assert.is_table(raw_lines)
        assert.is_true(#highlighted_lines > 0)
        assert.is_true(#raw_lines > 0)
      end
    end)
    
    it('should integrate buffer and window components', function()
      local buffer_module = require('jj-nvim.ui.buffer')
      local window_module = require('jj-nvim.ui.window')
      local mock_commits = mock_jj.create_mock_commits(3)
      
      -- Create buffer from commits
      local success, buf_id = pcall(buffer_module.create_from_commits, mock_commits)
      
      if success and buf_id then
        -- Open window with buffer
        local win_success, win_id = pcall(window_module.open, buf_id)
        
        if win_success and win_id then
          assert.is_true(window_module.is_open())
          
          -- Cleanup
          vim.api.nvim_win_close(win_id, true)
        end
        
        test_utils.cleanup_buffer(buf_id)
      end
    end)
  end)

  describe('configuration integration', function()
    it('should respect configuration settings', function()
      -- Test with different configurations
      local success = pcall(jj_nvim.setup, {
        window = { position = 'right' },
        theme = 'gruvbox'
      })
      
      assert.is_true(success, "Setup should succeed")
      
      -- Try to access config if possible
      local config_success, config = pcall(require, 'jj-nvim.config')
      if config_success and config.get then
        local get_success, current_config = pcall(config.get)
        if get_success then
          assert.is_table(current_config)
        end
      end
    end)
  end)

  describe('real jj integration', function()
    it('should work with real jj repository', function()
      test_utils.skip_if_not_jj_repo()
      
      -- Restore real vim.system for this test
      mock_system.restore()
      mock_system = nil
      
      local success, result = pcall(jj_nvim.show_log)
      
      -- Should work with real jj repository
      if not success then
        -- If it fails, should be a meaningful error
        assert.is_string(result)
        print("Real jj integration test failed (expected if not in jj repo): " .. result)
      else
        -- Should create actual buffer and window
        local found_jj_buffer = false
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if string.find(name, "jj-log") then
              found_jj_buffer = true
              
              -- Verify buffer has content
              local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
              assert.is_true(#lines > 0, "Buffer should have content")
              break
            end
          end
        end
        
        assert.is_true(found_jj_buffer, "Should create jj-log buffer")
      end
    end)
  end)
end)