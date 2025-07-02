#!/usr/bin/env lua

-- Simple test to verify the dynamic help and configurable keybinds work
local function test_keymap_registry()
  -- Mock vim API for testing
  _G.vim = {
    tbl_deep_extend = function(behavior, ...)
      local result = {}
      for _, tbl in ipairs({...}) do
        for k, v in pairs(tbl) do
          if type(v) == "table" and type(result[k]) == "table" then
            result[k] = vim.tbl_deep_extend(behavior, result[k], v)
          else
            result[k] = v
          end
        end
      end
      return result
    end,
    split = function(str, sep)
      local fields = {}
      local pattern = string.format("([^%s]+)", sep)
      str:gsub(pattern, function(c) fields[#fields+1] = c end)
      return fields
    end
  }
  
  -- Test the keymap registry
  local keymap_registry = require('jj-nvim.utils.keymap_registry')
  
  -- Mock config for testing
  local mock_config = {
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
  
  -- Initialize registry
  keymap_registry.initialize(mock_config)
  
  -- Test registry functions
  print("Testing keymap registry...")
  
  -- Test getting navigation keymaps
  local nav_keymaps = keymap_registry.get_category("navigation", "main")
  print("Navigation keymaps found:", next(nav_keymaps) and "YES" or "NO")
  
  -- Test registering menu items
  keymap_registry.register_menu_items("commit", {
    {key = "q", description = "Quick commit"},
    {key = "i", description = "Interactive commit"}
  })
  
  local commit_menu = keymap_registry.get_menu_items("commit")
  print("Menu items registered:", next(commit_menu) and "YES" or "NO")
  
  -- Test key formatting
  local formatted_key = keymap_registry.format_key("<CR>")
  print("Key formatting test:", formatted_key == "Enter" and "PASS" or "FAIL")
  
  print("✓ Keymap registry tests completed")
end

-- Test dynamic help content generation
local function test_help_generation()
  print("\nTesting help content generation...")
  
  -- This would need to be tested in a real Neovim environment
  -- since it depends on the actual plugin structure
  print("✓ Help generation test skipped (requires Neovim environment)")
end

-- Run tests
print("=== Testing Dynamic Help and Configurable Keybinds ===")
test_keymap_registry()
test_help_generation()
print("\n=== All tests completed ===")