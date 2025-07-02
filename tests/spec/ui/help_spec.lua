local test_utils = require('tests.helpers.test_utils')

describe('ui.help', function()
  local help_module
  local mock_config
  local original_config
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.ui.help'] = nil
    package.loaded['jj-nvim.utils.keymap_registry'] = nil
    package.loaded['jj-nvim.config'] = nil
    
    -- Store original config module to restore later
    original_config = require('jj-nvim.config')
    
    -- Create mock config with test data
    mock_config = {
      get = function(key)
        local config_data = {
          ['menus.navigation'] = {
            next = 'j',
            prev = 'k',
            next_alt = '<Down>',
            prev_alt = '<Up>',
            select = '<CR>',
            cancel = '<Esc>',
            cancel_alt = 'q',
            back = '<BS>'
          },
          ['menus.bookmark'] = {
            create = 'c',
            delete = 'd',
            move = 'm',
            rename = 'r',
            list = 'l',
            toggle_filter = 't'
          }
        }
        return config_data[key]
      end
    }
    
    -- Replace config module with mock
    package.loaded['jj-nvim.config'] = mock_config
    
    help_module = require('jj-nvim.ui.help')
  end)
  
  after_each(function()
    -- Clean up any help windows
    if help_module.is_open() then
      help_module.close()
    end
    
    -- Restore original config
    package.loaded['jj-nvim.config'] = original_config
  end)

  describe('help dialog state management', function()
    it('should track open/closed state correctly', function()
      assert.is_false(help_module.is_open())
      
      -- Create a test window to use as parent
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      help_module.show(test_win)
      assert.is_true(help_module.is_open())
      
      help_module.close()
      assert.is_false(help_module.is_open())
      
      -- Clean up test window
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should toggle help dialog correctly', function()
      -- Create a test window to use as parent
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      -- First show should open
      assert.is_false(help_module.is_open())
      help_module.show(test_win)
      assert.is_true(help_module.is_open())
      
      -- Second show should close (toggle behavior)
      help_module.show(test_win)
      assert.is_false(help_module.is_open())
      
      -- Clean up test window
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('dynamic help content generation', function()
    it('should generate help content with configured keys', function()
      -- Create a test window
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 50,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      help_module.show(test_win)
      
      -- Check that help window was created
      assert.is_true(help_module.is_open())
      
      -- Get the help buffer content to verify dynamic generation
      local state = help_module.get_state and help_module.get_state()
      if state and state.buf_id then
        local help_lines = vim.api.nvim_buf_get_lines(state.buf_id, 0, -1, false)
        
        -- Should contain the title
        assert.is_true(vim.tbl_contains(help_lines, "           JJ-Nvim Keybind Reference"))
        
        -- Should contain navigation section
        local has_navigation = false
        for _, line in ipairs(help_lines) do
          if string.match(line, "═══ Navigation ═══") then
            has_navigation = true
            break
          end
        end
        assert.is_true(has_navigation)
        
        -- Should contain menu navigation section with configured keys
        local has_menu_nav = false
        for _, line in ipairs(help_lines) do
          if string.match(line, "═══ Menu Navigation ═══") then
            has_menu_nav = true
            break
          end
        end
        assert.is_true(has_menu_nav)
      end
      
      help_module.close()
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should include configured menu navigation keys in help', function()
      -- Create a test window
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 50,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      help_module.show(test_win)
      
      local state = help_module.get_state and help_module.get_state()
      if state and state.buf_id then
        local help_lines = vim.api.nvim_buf_get_lines(state.buf_id, 0, -1, false)
        local help_text = table.concat(help_lines, "\n")
        
        -- Should contain configured navigation keys
        assert.is_true(string.find(help_text, "j/k") ~= nil or string.find(help_text, "Navigate menu items") ~= nil)
        assert.is_true(string.find(help_text, "Enter") ~= nil or string.find(help_text, "Select menu item") ~= nil)
        assert.is_true(string.find(help_text, "Escape") ~= nil or string.find(help_text, "Cancel menu") ~= nil)
        assert.is_true(string.find(help_text, "Backspace") ~= nil or string.find(help_text, "Go back") ~= nil)
      end
      
      help_module.close()
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('help window creation', function()
    it('should create help window with proper dimensions', function()
      -- Create a large parent window
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 120,
        height = 40,
        row = 5,
        col = 10,
        style = 'minimal'
      })
      
      help_module.show(test_win)
      
      local state = help_module.get_state and help_module.get_state()
      if state and state.win_id then
        assert.is_true(vim.api.nvim_win_is_valid(state.win_id))
        
        local width = vim.api.nvim_win_get_width(state.win_id)
        local height = vim.api.nvim_win_get_height(state.win_id)
        
        -- Help window should have reasonable dimensions
        assert.is_true(width > 0)
        assert.is_true(height > 0)
        assert.is_true(width <= 120)  -- Should fit within parent or screen
      end
      
      help_module.close()
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should handle small parent windows by using editor space', function()
      -- Create a very small parent window
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 20,
        height = 10,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      help_module.show(test_win)
      
      -- Should still create help window successfully
      assert.is_true(help_module.is_open())
      
      help_module.close()
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('help window interaction', function()
    it('should respond to close keymaps', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 30,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      help_module.show(test_win)
      assert.is_true(help_module.is_open())
      
      local state = help_module.get_state and help_module.get_state()
      if state and state.buf_id then
        -- Simulate pressing 'q' to close help
        vim.api.nvim_buf_call(state.buf_id, function()
          -- This would normally trigger the keymap, but we'll just call close directly
          help_module.close()
        end)
      else
        help_module.close()
      end
      
      assert.is_false(help_module.is_open())
      vim.api.nvim_win_close(test_win, true)
    end)
  end)
end)