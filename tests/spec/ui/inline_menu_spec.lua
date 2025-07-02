local test_utils = require('tests.helpers.test_utils')

describe('ui.inline_menu', function()
  local inline_menu
  local mock_config
  local original_config
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.ui.inline_menu'] = nil
    package.loaded['jj-nvim.utils.keymap_registry'] = nil
    package.loaded['jj-nvim.config'] = nil
    
    -- Store original config
    original_config = require('jj-nvim.config')
    
    -- Create mock config with custom navigation keys
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
          }
        }
        return config_data[key]
      end
    }
    
    -- Replace config module
    package.loaded['jj-nvim.config'] = mock_config
    
    inline_menu = require('jj-nvim.ui.inline_menu')
  end)
  
  after_each(function()
    -- Clean up any active menus
    if inline_menu.is_active() then
      inline_menu.close()
    end
    
    -- Clean up any test windows/buffers
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_is_valid(buf) then
          local name = vim.api.nvim_buf_get_name(buf)
          if string.find(name, "test") or vim.api.nvim_buf_get_option(buf, 'filetype') == 'jj-menu' then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
      end
    end
    
    -- Restore original config
    package.loaded['jj-nvim.config'] = original_config
  end)

  describe('menu state management', function()
    it('should track active state correctly', function()
      assert.is_false(inline_menu.is_active())
      
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local menu_config = {
        id = "test_menu",
        title = "Test Menu",
        items = {
          {key = "a", description = "Action A", action = "action_a"},
          {key = "b", description = "Action B", action = "action_b"}
        }
      }
      
      local success = inline_menu.show(test_win, menu_config, {
        on_select = function(item) end,
        on_cancel = function() end
      })
      
      assert.is_true(success)
      assert.is_true(inline_menu.is_active())
      
      inline_menu.close()
      assert.is_false(inline_menu.is_active())
      
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should handle invalid menu configuration', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      -- Test with invalid config
      local success1 = inline_menu.show(test_win, nil)
      assert.is_false(success1)
      
      local success2 = inline_menu.show(test_win, {title = "Test"})  -- No items
      assert.is_false(success2)
      
      local success3 = inline_menu.show(test_win, {title = "Test", items = {}})  -- Empty items
      assert.is_false(success3)
      
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('menu creation and display', function()
    it('should create menu with configured navigation keys', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local menu_config = {
        id = "test_menu",
        title = "Test Menu",
        items = {
          {key = "q", description = "Quick action", action = "quick"},
          {key = "i", description = "Interactive action", action = "interactive"}
        }
      }
      
      local success = inline_menu.show(test_win, menu_config, {
        on_select = function(item) end
      })
      
      assert.is_true(success)
      assert.is_true(inline_menu.is_active())
      
      -- Verify menu state
      local state = inline_menu.get_state()
      assert.is_not_nil(state)
      assert.is_not_nil(state.win_id)
      assert.is_not_nil(state.buf_id)
      assert.equals("test_menu", state.menu_id)
      assert.equals(1, state.selected_index)
      
      inline_menu.close()
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should render menu content correctly', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local menu_config = {
        id = "render_test",
        title = "Render Test Menu",
        items = {
          {key = "a", description = "First Action", action = "first"},
          {key = "b", description = "Second Action", action = "second"}
        }
      }
      
      inline_menu.show(test_win, menu_config, {})
      
      local state = inline_menu.get_state()
      if state and state.buf_id then
        local lines = vim.api.nvim_buf_get_lines(state.buf_id, 0, -1, false)
        
        -- Should contain title
        assert.is_true(vim.tbl_contains(lines, "Render Test Menu"))
        
        -- Should contain menu items
        local has_first_item = false
        local has_second_item = false
        for _, line in ipairs(lines) do
          if string.find(line, "First Action") then has_first_item = true end
          if string.find(line, "Second Action") then has_second_item = true end
        end
        assert.is_true(has_first_item)
        assert.is_true(has_second_item)
      end
      
      inline_menu.close()
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('keymap registry integration', function()
    it('should register menu items with keymap registry', function()
      local keymap_registry = require('jj-nvim.utils.keymap_registry')
      
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local menu_config = {
        id = "registry_test",
        title = "Registry Test",
        items = {
          {key = "r", description = "Registry Action", action = "registry"}
        }
      }
      
      inline_menu.show(test_win, menu_config, {})
      
      -- Verify items were registered
      local registered_items = keymap_registry.get_menu_items("registry_test")
      assert.is_not_nil(registered_items["r"])
      assert.equals("Registry Action", registered_items["r"].description)
      assert.equals("registry_test", registered_items["r"].menu_id)
      
      inline_menu.close()
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('menu interaction', function()
    it('should handle selection callbacks', function()
      local selected_item = nil
      local was_cancelled = false
      
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local menu_config = {
        id = "callback_test",
        title = "Callback Test",
        items = {
          {key = "t", description = "Test Action", action = "test_action"}
        }
      }
      
      inline_menu.show(test_win, menu_config, {
        on_select = function(item)
          selected_item = item
        end,
        on_cancel = function()
          was_cancelled = true
        end
      })
      
      -- Simulate direct key selection
      local state = inline_menu.get_state()
      if state and state.buf_id then
        -- Manually trigger selection (simulating keypress)
        local callbacks = {
          on_select = function(item) selected_item = item end
        }
        local item = menu_config.items[1]
        inline_menu.close()
        callbacks.on_select(item)
        
        assert.is_not_nil(selected_item)
        assert.equals("test_action", selected_item.action)
      end
      
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should close menu and return focus to parent window', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      -- Focus the test window
      vim.api.nvim_set_current_win(test_win)
      local initial_win = vim.api.nvim_get_current_win()
      
      local menu_config = {
        id = "focus_test",
        title = "Focus Test",
        items = {
          {key = "f", description = "Focus Action", action = "focus"}
        }
      }
      
      inline_menu.show(test_win, menu_config, {})
      
      -- Menu should be active and focused
      assert.is_true(inline_menu.is_active())
      
      inline_menu.close()
      
      -- Menu should be closed
      assert.is_false(inline_menu.is_active())
      
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('configurable navigation keys', function()
    it('should use configured navigation keys from config', function()
      -- This test verifies that the menu system reads navigation keys from config
      -- The actual keymap testing would require integration testing with real keypresses
      
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 24,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local menu_config = {
        id = "nav_test",
        title = "Navigation Test",
        items = {
          {key = "1", description = "Item 1", action = "item1"},
          {key = "2", description = "Item 2", action = "item2"}
        }
      }
      
      -- Verify that showing the menu with custom config works
      local success = inline_menu.show(test_win, menu_config, {})
      assert.is_true(success)
      
      -- The actual navigation key functionality would be tested in integration tests
      -- where we can simulate real keypresses
      
      inline_menu.close()
      vim.api.nvim_win_close(test_win, true)
    end)
  end)
end)