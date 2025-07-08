local M = {}

local config = require('jj-nvim.config')

-- Helper function to get menu keybinds from config
-- Consolidates keybind retrieval patterns from commit.lua, squash.lua, etc.
M.get_menu_keybinds = function(menu_name, fallback_keys)
  local primary_key = string.format('keybinds.menus.%s', menu_name)
  local fallback_key = string.format('menus.%s', menu_name)
  
  return config.get(primary_key) or config.get(fallback_key) or fallback_keys or {}
end

-- Helper function to create standardized menu configuration
-- Consolidates menu creation patterns from commit.lua, squash.lua, etc.
M.create_operation_menu = function(operation_name, menu_items_config, options)
  options = options or {}
  
  local menu_keys = M.get_menu_keybinds(operation_name, options.fallback_keys)
  local menu_config = {
    id = operation_name,
    title = options.title or string.format("%s Options", operation_name:gsub("^%l", string.upper)),
    items = {}
  }
  
  -- Build menu items from config
  for _, item_config in ipairs(menu_items_config) do
    local key = menu_keys[item_config.key_name] or item_config.default_key
    if key then
      table.insert(menu_config.items, {
        key = key,
        description = item_config.description,
        action = item_config.action,
        enabled = item_config.enabled ~= false, -- Default to enabled
      })
    end
  end
  
  return menu_config
end

-- Helper function to create standard operation menu items
-- Provides common menu item configurations for operations
M.create_standard_operation_items = function(operation_name)
  return {
    {
      key_name = "quick",
      default_key = "q",
      description = string.format("Quick %s", operation_name),
      action = "quick"
    },
    {
      key_name = "interactive",
      default_key = "i", 
      description = string.format("Interactive %s", operation_name),
      action = "interactive"
    },
    {
      key_name = "with_message",
      default_key = "m",
      description = string.format("%s with message", operation_name),
      action = "with_message"
    }
  }
end

-- Helper function to create target selection menu items
-- Used for operations that need target selection (squash, rebase, etc.)
M.create_target_selection_items = function(operation_name, target_types)
  target_types = target_types or { "destination", "insert_after", "insert_before" }
  
  local items = {}
  for _, target_type in ipairs(target_types) do
    local key_name = target_type:gsub("_", "")
    local description = string.format("%s %s", operation_name, target_type:gsub("_", " "))
    
    table.insert(items, {
      key_name = key_name,
      default_key = target_type:sub(1, 1), -- First letter as default
      description = description,
      action = target_type
    })
  end
  
  return items
end

return M