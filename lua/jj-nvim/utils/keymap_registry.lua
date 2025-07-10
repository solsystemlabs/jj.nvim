local M = {}

-- Registry to store all keymaps with their descriptions and categories
M.registry = {
  navigation = {},
  actions = {},
  selection = {},
  git_operations = {},
  bookmarks = {},
  revsets = {},
  window_controls = {},
  target_selection = {},
  multi_select = {},
  menu_navigation = {},
  help = {},
  menu_items = {}  -- For dynamic menu item keys
}

-- Current configuration cache
M.config_cache = nil

-- Register a keymap with description and category
M.register = function(category, key, description, mode)
  mode = mode or "main"  -- main, target_selection, multi_select, menu
  
  if not M.registry[category] then
    M.registry[category] = {}
  end
  
  if not M.registry[category][mode] then
    M.registry[category][mode] = {}
  end
  
  -- Store keymap info
  M.registry[category][mode][key] = {
    key = key,
    description = description,
    category = category,
    mode = mode
  }
end

-- Register multiple keymaps at once
M.register_batch = function(category, keymaps, mode)
  mode = mode or "main"
  for key, description in pairs(keymaps) do
    M.register(category, key, description, mode)
  end
end

-- Get all keymaps for a specific category and mode
M.get_category = function(category, mode)
  mode = mode or "main"
  if not M.registry[category] or not M.registry[category][mode] then
    return {}
  end
  return M.registry[category][mode]
end

-- Get all keymaps for a specific mode
M.get_mode = function(mode)
  mode = mode or "main"
  local result = {}
  
  for category, modes in pairs(M.registry) do
    if modes[mode] then
      result[category] = modes[mode]
    end
  end
  
  return result
end

-- Get all keymaps organized by category
M.get_all = function()
  return M.registry
end

-- Clear all registered keymaps
M.clear = function()
  M.registry = {
    navigation = {},
    actions = {},
    selection = {},
    git_operations = {},
    bookmarks = {},
    revsets = {},
    window_controls = {},
    target_selection = {},
    multi_select = {},
    menu_navigation = {},
    help = {},
    menu_items = {}
  }
  M.config_cache = nil
end

-- Initialize registry with keymaps from config 
M.initialize = function(config)
  M.config_cache = config
  M.clear()
  
  -- Get keybinds from config (with backward compatibility)
  local log_navigation = config.get('keybinds.log_window.navigation') or {}
  local log_actions = config.get('keybinds.log_window.actions') or {}
  local legacy_keymaps = config.get('keymaps') or {}
  
  -- Main window navigation keymaps - read from new config structure with fallbacks
  M.register_batch("navigation", {
    [log_navigation.next_commit or legacy_keymaps.next_commit or "j"] = "Navigate commits",
    [log_navigation.prev_commit or legacy_keymaps.prev_commit or "k"] = "Navigate commits", 
    [log_navigation.jump_next or "<Down>"] = "Alternative navigation",
    [log_navigation.jump_prev or "<Up>"] = "Alternative navigation",
    ["J"] = "Navigate commits (centered)",
    ["K"] = "Navigate commits (centered)",
    ["gg"] = "Go to first commit",
    ["G"] = "Go to last commit",
    ["@"] = "Go to current commit"
  })
  
  M.register_batch("actions", {
    [log_actions.show_diff or legacy_keymaps.show_diff or "<CR>"] = "Show diff for commit",
    ["d"] = "Show diff (alternative)",
    ["D"] = "Show diff summary/stats", 
    [log_actions.edit_message or legacy_keymaps.edit_message or "e"] = "Edit commit",
    ["m"] = "Set commit description",
    [log_actions.abandon or legacy_keymaps.abandon or "a"] = "Abandon commit(s) - smart",
    ["A"] = "Abandon selected commits",
    [log_actions.squash or legacy_keymaps.squash or "x"] = "Squash commit (select target)",
    [log_actions.split or legacy_keymaps.split or "s"] = "Split commit (options menu)",
    [log_actions.rebase or legacy_keymaps.rebase or "r"] = "Rebase commit (options menu)",
    ["n"] = "New change (quick)",
    ["N"] = "New change (options menu)",
    [log_actions.undo or "u"] = "Undo last operation"
  })
  
  M.register_batch("selection", {
    ["<Esc>"] = "Clear selections or close",
    ["<Tab>"] = "Toggle description expansion"
  })
  
  M.register_batch("git_operations", {
    ["f"] = "Fetch from remote",
    ["p"] = "Push to remote", 
    ["S"] = "Show repository status",
    ["c"] = "Quick commit working copy",
    ["C"] = "Commit with options menu"
  })
  
  M.register_batch("bookmarks", {
    ["b"] = "Bookmark operations menu"
  })
  
  M.register_batch("revsets", {
    ["rs"] = "Show revset preset menu",
    ["rr"] = "Enter custom revset"
  })
  
  M.register_batch("window_controls", {
    [log_actions.close or legacy_keymaps.close or "q"] = "Close window",
    ["R"] = "Refresh commits",
    ["+"] = "Adjust width (large)",
    ["-"] = "Adjust width (large)",
    ["="] = "Adjust width (small)",
    ["_"] = "Adjust width (small)"
  })
  
  M.register_batch("help", {
    ["?"] = "Show/hide this help"
  })
  
  -- Target selection mode
  M.register_batch("target_selection", {
    ["<CR>"] = "Confirm target selection",
    ["<Esc>"] = "Cancel target selection",
    ["b"] = "Show bookmark selection (squash)"
  }, "target_selection")
  
  -- Multi-select mode
  M.register_batch("multi_select", {
    ["<Space>"] = "Toggle commit selection", 
    ["<CR>"] = "Confirm selection & merge",
    ["<Esc>"] = "Cancel multi-selection"
  }, "multi_select")
  
  -- Menu navigation (use configured keys with backward compatibility)
  local nav_keys = config.get('keybinds.menu_navigation') or config.get('menus.navigation') or {
    next = 'j', prev = 'k', jump_next = '<Down>', jump_prev = '<Up>', 
    select = '<CR>', cancel = {'<Esc>', 'q'}, back = '<BS>'
  }
  
  -- Handle backward compatibility for old key names
  if not nav_keys.jump_next and nav_keys.next_alt then
    nav_keys.jump_next = nav_keys.next_alt
  end
  if not nav_keys.jump_prev and nav_keys.prev_alt then
    nav_keys.jump_prev = nav_keys.prev_alt
  end
  
  -- Handle cancel arrays and old cancel_alt
  local cancel_keys = {}
  if type(nav_keys.cancel) == "table" then
    cancel_keys = nav_keys.cancel
  elseif nav_keys.cancel then
    table.insert(cancel_keys, nav_keys.cancel)
  end
  if nav_keys.cancel_alt then
    table.insert(cancel_keys, nav_keys.cancel_alt)
  end
  
  local menu_nav_keymap = {
    [nav_keys.next] = "Navigate menu items",
    [nav_keys.prev] = "Navigate menu items",
    [nav_keys.select] = "Select menu item",
    [nav_keys.back] = "Go back (parent menu)"
  }
  
  -- Add jump navigation if available
  if nav_keys.jump_next then
    menu_nav_keymap[nav_keys.jump_next] = "Navigate menu items"
  end
  if nav_keys.jump_prev then
    menu_nav_keymap[nav_keys.jump_prev] = "Navigate menu items"
  end
  
  -- Add cancel keys
  for _, cancel_key in ipairs(cancel_keys) do
    menu_nav_keymap[cancel_key] = "Cancel menu"
  end
  
  M.register_batch("menu_navigation", menu_nav_keymap, "menu")
end

-- Add dynamic menu items (called when menus are created)
M.register_menu_items = function(menu_id, items)
  if not M.registry.menu_items.menu then
    M.registry.menu_items.menu = {}
  end
  
  M.registry.menu_items.menu[menu_id] = {}
  
  for _, item in ipairs(items) do
    M.registry.menu_items.menu[menu_id][item.key] = {
      key = item.key,
      description = item.description,
      category = "menu_items",
      mode = "menu",
      menu_id = menu_id
    }
  end
end

-- Get menu items for a specific menu
M.get_menu_items = function(menu_id)
  if not M.registry.menu_items.menu or not M.registry.menu_items.menu[menu_id] then
    return {}
  end
  return M.registry.menu_items.menu[menu_id]
end

-- Helper to get display-friendly key name
M.format_key = function(key)
  local key_mappings = {
    ["<CR>"] = "Enter",
    ["<Esc>"] = "Escape", 
    ["<Space>"] = "Space",
    ["<Tab>"] = "Tab",
    ["<BS>"] = "Backspace",
    ["<Up>"] = "↑",
    ["<Down>"] = "↓",
    ["<Left>"] = "←",
    ["<Right>"] = "→"
  }
  
  return key_mappings[key] or key
end

-- Reload the registry (useful when config changes)
M.reload = function()
  if M.config_cache then
    M.initialize(M.config_cache)
  end
end

return M