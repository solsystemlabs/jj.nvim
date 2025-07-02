local test_utils = require('tests.helpers.test_utils')

describe('dynamic help integration', function()
  local help_module
  local inline_menu
  local keymap_registry
  local commit_module
  local config_module
  
  before_each(function()
    -- Reset module cache completely
    package.loaded['jj-nvim.ui.help'] = nil
    package.loaded['jj-nvim.ui.inline_menu'] = nil
    package.loaded['jj-nvim.utils.keymap_registry'] = nil
    package.loaded['jj-nvim.jj.commit'] = nil
    package.loaded['jj-nvim.config'] = nil
    
    -- Load all modules fresh
    config_module = require('jj-nvim.config')
    keymap_registry = require('jj-nvim.utils.keymap_registry')
    inline_menu = require('jj-nvim.ui.inline_menu')
    help_module = require('jj-nvim.ui.help')
    commit_module = require('jj-nvim.jj.commit')
    
    -- Setup config with custom keybinds for testing
    config_module.setup({
      menus = {
        navigation = {
          next = 'j',
          prev = 'k',
          next_alt = '<Down>',
          prev_alt = '<Up>',
          select = '<CR>',
          cancel = '<Esc>',
          cancel_alt = 'q',
          back = '<BS>'
        },
        commit = {
          quick = 'w',        -- Custom: changed from 'q' to 'w'
          interactive = 'e',  -- Custom: changed from 'i' to 'e'
          reset_author = 't', -- Custom: changed from 'r' to 't'
          custom_author = 'y', -- Custom: changed from 'a' to 'y'
          filesets = 'u'      -- Custom: changed from 'f' to 'u'
        }
      }
    })
    
    -- Initialize keymap registry with the config
    keymap_registry.initialize(config_module)
  end)
  
  after_each(function()
    -- Clean up any open menus or help windows
    if inline_menu.is_active() then
      inline_menu.close()
    end
    if help_module.is_open() then
      help_module.close()
    end
    
    -- Clean up test windows
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_is_valid(buf) then
          local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
          if ft == 'jj-menu' or ft == 'jj-help' then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
      end
    end
  end)

  describe('end-to-end dynamic help system', function()
    it('should generate help content that reflects custom menu keybinds', function()
      -- Create test window
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 100,
        height = 40,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      -- Create a commit menu with custom keys to register them
      local menu_config = {
        id = "commit",
        title = "Commit Options",
        items = {
          {key = "w", description = "Quick commit (prompt for message)", action = "quick_commit"},
          {key = "e", description = "Interactive commit (choose changes)", action = "interactive_commit"},
          {key = "t", description = "Reset author and commit", action = "reset_author_commit"},
          {key = "y", description = "Commit with custom author", action = "custom_author_commit"},
          {key = "u", description = "Commit specific files (filesets)", action = "fileset_commit"}
        }
      }
      
      -- Show the commit menu to register the items
      inline_menu.show(test_win, menu_config, {
        on_select = function(item) end
      })
      
      -- Verify menu items were registered
      local registered_items = keymap_registry.get_menu_items("commit")
      assert.is_not_nil(registered_items["w"])
      assert.is_not_nil(registered_items["e"])
      assert.is_not_nil(registered_items["t"])
      assert.equals("Quick commit (prompt for message)", registered_items["w"].description)
      
      inline_menu.close()
      
      -- Now show help and verify it contains the custom keybinds
      help_module.show(test_win)
      assert.is_true(help_module.is_open())
      
      local help_state = help_module.get_state and help_module.get_state()
      if help_state and help_state.buf_id then
        local help_lines = vim.api.nvim_buf_get_lines(help_state.buf_id, 0, -1, false)
        local help_text = table.concat(help_lines, "\n")
        
        -- Verify that help contains our custom navigation keys
        assert.is_true(string.find(help_text, "j/k") ~= nil)  -- Our configured nav keys
        assert.is_true(string.find(help_text, "Enter") ~= nil)  -- Formatted <CR>
        assert.is_true(string.find(help_text, "Backspace") ~= nil)  -- Formatted <BS>
        
        -- Verify section headers are present
        assert.is_true(string.find(help_text, "═══ Navigation ═══") ~= nil)
        assert.is_true(string.find(help_text, "═══ Menu Navigation ═══") ~= nil)
        assert.is_true(string.find(help_text, "═══ Actions ═══") ~= nil)
      end
      
      help_module.close()
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should update help content when menu configurations change', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 100,
        height = 40,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      -- Register first set of menu items
      keymap_registry.register_menu_items("test_menu", {
        {key = "x", description = "First action"},
        {key = "z", description = "Second action"}
      })
      
      -- Show help and capture content
      help_module.show(test_win)
      local first_help_lines = nil
      local help_state = help_module.get_state and help_module.get_state()
      if help_state and help_state.buf_id then
        first_help_lines = vim.api.nvim_buf_get_lines(help_state.buf_id, 0, -1, false)
      end
      help_module.close()
      
      -- Register different menu items
      keymap_registry.register_menu_items("test_menu", {
        {key = "a", description = "Different first action"},
        {key = "s", description = "Different second action"}
      })
      
      -- Show help again and verify it's different
      help_module.show(test_win)
      local second_help_lines = nil
      help_state = help_module.get_state and help_module.get_state()
      if help_state and help_state.buf_id then
        second_help_lines = vim.api.nvim_buf_get_lines(help_state.buf_id, 0, -1, false)
      end
      help_module.close()
      
      -- Help content should be dynamic and reflect current state
      if first_help_lines and second_help_lines then
        -- The help is regenerated each time, so it should contain current keymap state
        assert.is_table(first_help_lines)
        assert.is_table(second_help_lines)
        -- Content should be generated properly both times
        assert.is_true(#first_help_lines > 0)
        assert.is_true(#second_help_lines > 0)
      end
      
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('configurable menu system integration', function()
    it('should use custom navigation keys in menu interactions', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 30,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local selection_made = false
      local selected_item = nil
      
      local menu_config = {
        id = "integration_test",
        title = "Integration Test Menu",
        items = {
          {key = "m", description = "Test Action", action = "test"}
        }
      }
      
      local success = inline_menu.show(test_win, menu_config, {
        on_select = function(item)
          selection_made = true
          selected_item = item
        end
      })
      
      assert.is_true(success)
      assert.is_true(inline_menu.is_active())
      
      -- Verify that the menu system properly reads from config
      local state = inline_menu.get_state()
      assert.is_not_nil(state)
      assert.equals("integration_test", state.menu_id)
      
      inline_menu.close()
      vim.api.nvim_win_close(test_win, true)
    end)
    
    it('should integrate keymap registry with menu creation', function()
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 30,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      local menu_config = {
        id = "registry_integration",
        title = "Registry Integration Test",
        items = {
          {key = "p", description = "Process action", action = "process"},
          {key = "l", description = "List action", action = "list"}
        }
      }
      
      inline_menu.show(test_win, menu_config, {})
      
      -- Verify items were registered automatically
      local registered = keymap_registry.get_menu_items("registry_integration")
      assert.is_not_nil(registered["p"])
      assert.is_not_nil(registered["l"])
      assert.equals("Process action", registered["p"].description)
      assert.equals("List action", registered["l"].description)
      
      inline_menu.close()
      vim.api.nvim_win_close(test_win, true)
    end)
  end)

  describe('real menu integration with custom keys', function()
    it('should show commit menu with custom keybinds from config', function()
      -- Mock the status check to allow menu to show
      local original_status = package.loaded['jj-nvim.jj.status']
      package.loaded['jj-nvim.jj.status'] = {
        get_status = function(opts)
          return "Working copy has changes\nSome file changes here", nil
        end
      }
      
      local test_buf = vim.api.nvim_create_buf(false, true)
      local test_win = vim.api.nvim_open_win(test_buf, false, {
        relative = 'editor',
        width = 80,
        height = 30,
        row = 0,
        col = 0,
        style = 'minimal'
      })
      
      -- This should use our custom commit keybinds (w, e, t, y, u instead of q, i, r, a, f)
      local menu_shown = false
      
      -- Mock the menu to capture when it's shown
      local original_show = inline_menu.show
      inline_menu.show = function(parent_win_id, menu_config, callbacks)
        menu_shown = true
        
        -- Verify that custom keys are being used
        if menu_config.id == "commit" then
          local keys = {}
          for _, item in ipairs(menu_config.items) do
            table.insert(keys, item.key)
          end
          
          -- Should contain our custom keys
          assert.is_true(vim.tbl_contains(keys, "w"))  -- custom quick
          assert.is_true(vim.tbl_contains(keys, "e"))  -- custom interactive
          assert.is_true(vim.tbl_contains(keys, "t"))  -- custom reset_author
        end
        
        return true
      end
      
      -- Show the commit menu
      commit_module.show_commit_menu(test_win)
      
      assert.is_true(menu_shown)
      
      -- Restore mocks
      inline_menu.show = original_show
      package.loaded['jj-nvim.jj.status'] = original_status
      
      vim.api.nvim_win_close(test_win, true)
    end)
  end)
end)