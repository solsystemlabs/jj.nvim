local test_utils = require('tests.helpers.test_utils')

describe('utils.keymap_registry', function()
  local keymap_registry
  local mock_config
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.utils.keymap_registry'] = nil
    package.loaded['jj-nvim.config'] = nil
    
    -- Create mock config
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
          ['menus.commit'] = {
            quick = 'q',
            interactive = 'i',
            reset_author = 'r',
            custom_author = 'a',
            filesets = 'f'
          }
        }
        return config_data[key]
      end
    }
    
    keymap_registry = require('jj-nvim.utils.keymap_registry')
  end)
  
  after_each(function()
    -- Clear registry state
    keymap_registry.clear()
  end)

  describe('initialization', function()
    it('should initialize with config data', function()
      keymap_registry.initialize(mock_config)
      
      local nav_keymaps = keymap_registry.get_category("navigation", "main")
      assert.is_not_nil(next(nav_keymaps))
      
      -- Test specific navigation keymaps
      assert.is_not_nil(nav_keymaps["j"])
      assert.equals("Navigate commits", nav_keymaps["j"].description)
      assert.equals("navigation", nav_keymaps["j"].category)
      assert.equals("main", nav_keymaps["j"].mode)
    end)
    
    it('should register action keymaps', function()
      keymap_registry.initialize(mock_config)
      
      local action_keymaps = keymap_registry.get_category("actions", "main")
      assert.is_not_nil(next(action_keymaps))
      
      -- Test specific action keymaps
      assert.is_not_nil(action_keymaps["<CR>"])
      assert.equals("Show diff for commit", action_keymaps["<CR>"].description)
    end)
    
    it('should register target selection mode keymaps', function()
      keymap_registry.initialize(mock_config)
      
      local target_keymaps = keymap_registry.get_category("target_selection", "target_selection")
      assert.is_not_nil(next(target_keymaps))
      
      assert.is_not_nil(target_keymaps["<CR>"])
      assert.equals("Confirm target selection", target_keymaps["<CR>"].description)
    end)
  end)

  describe('keymap registration', function()
    it('should register individual keymaps', function()
      keymap_registry.register("test_category", "t", "Test keymap", "main")
      
      local test_keymaps = keymap_registry.get_category("test_category", "main")
      assert.is_not_nil(test_keymaps["t"])
      assert.equals("Test keymap", test_keymaps["t"].description)
      assert.equals("test_category", test_keymaps["t"].category)
    end)
    
    it('should register batch keymaps', function()
      local batch_keymaps = {
        ["a"] = "Action A",
        ["b"] = "Action B"
      }
      
      keymap_registry.register_batch("test_batch", batch_keymaps, "main")
      
      local test_keymaps = keymap_registry.get_category("test_batch", "main")
      assert.is_not_nil(test_keymaps["a"])
      assert.is_not_nil(test_keymaps["b"])
      assert.equals("Action A", test_keymaps["a"].description)
      assert.equals("Action B", test_keymaps["b"].description)
    end)
  end)

  describe('menu item registration', function()
    it('should register menu items dynamically', function()
      local menu_items = {
        {key = "q", description = "Quick action"},
        {key = "i", description = "Interactive action"}
      }
      
      keymap_registry.register_menu_items("test_menu", menu_items)
      
      local registered_items = keymap_registry.get_menu_items("test_menu")
      assert.is_not_nil(registered_items["q"])
      assert.is_not_nil(registered_items["i"])
      assert.equals("Quick action", registered_items["q"].description)
      assert.equals("test_menu", registered_items["q"].menu_id)
    end)
    
    it('should handle multiple menus', function()
      keymap_registry.register_menu_items("menu1", {{key = "a", description = "Action A"}})
      keymap_registry.register_menu_items("menu2", {{key = "b", description = "Action B"}})
      
      local menu1_items = keymap_registry.get_menu_items("menu1")
      local menu2_items = keymap_registry.get_menu_items("menu2")
      
      assert.is_not_nil(menu1_items["a"])
      assert.is_not_nil(menu2_items["b"])
      assert.is_nil(menu1_items["b"])
      assert.is_nil(menu2_items["a"])
    end)
  end)

  describe('data retrieval', function()
    before_each(function()
      keymap_registry.initialize(mock_config)
    end)
    
    it('should get keymaps by category and mode', function()
      local nav_keymaps = keymap_registry.get_category("navigation", "main")
      local target_keymaps = keymap_registry.get_category("target_selection", "target_selection")
      
      assert.is_not_nil(next(nav_keymaps))
      assert.is_not_nil(next(target_keymaps))
      
      -- Should be different sets
      assert.is_not_nil(nav_keymaps["j"])
      assert.is_nil(target_keymaps["j"])
    end)
    
    it('should get all keymaps for a mode', function()
      local main_keymaps = keymap_registry.get_mode("main")
      
      assert.is_not_nil(main_keymaps.navigation)
      assert.is_not_nil(main_keymaps.actions)
      assert.is_not_nil(main_keymaps.selection)
      
      -- Should have navigation keymaps
      assert.is_not_nil(main_keymaps.navigation["j"])
    end)
    
    it('should return empty table for unknown categories', function()
      local unknown_keymaps = keymap_registry.get_category("unknown", "main")
      assert.is_table(unknown_keymaps)
      assert.is_nil(next(unknown_keymaps))
    end)
  end)

  describe('key formatting', function()
    it('should format special keys correctly', function()
      assert.equals("Enter", keymap_registry.format_key("<CR>"))
      assert.equals("Escape", keymap_registry.format_key("<Esc>"))
      assert.equals("Space", keymap_registry.format_key("<Space>"))
      assert.equals("Tab", keymap_registry.format_key("<Tab>"))
      assert.equals("Backspace", keymap_registry.format_key("<BS>"))
      assert.equals("↑", keymap_registry.format_key("<Up>"))
      assert.equals("↓", keymap_registry.format_key("<Down>"))
    end)
    
    it('should return regular keys unchanged', function()
      assert.equals("j", keymap_registry.format_key("j"))
      assert.equals("k", keymap_registry.format_key("k"))
      assert.equals("a", keymap_registry.format_key("a"))
      assert.equals("?", keymap_registry.format_key("?"))
    end)
  end)

  describe('clear functionality', function()
    it('should clear all registered keymaps', function()
      keymap_registry.initialize(mock_config)
      keymap_registry.register_menu_items("test", {{key = "t", description = "Test"}})
      
      -- Verify data exists
      local nav_keymaps = keymap_registry.get_category("navigation", "main")
      local menu_items = keymap_registry.get_menu_items("test")
      assert.is_not_nil(next(nav_keymaps))
      assert.is_not_nil(next(menu_items))
      
      -- Clear and verify empty
      keymap_registry.clear()
      nav_keymaps = keymap_registry.get_category("navigation", "main")
      menu_items = keymap_registry.get_menu_items("test")
      assert.is_nil(next(nav_keymaps))
      assert.is_nil(next(menu_items))
    end)
  end)
end)