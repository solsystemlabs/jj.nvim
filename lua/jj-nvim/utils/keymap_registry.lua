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
  
  -- Get keybinds from config
  local keymaps = config.get('keymaps') or {}
  
  -- Main window keymaps - read from config
  M.register_batch("navigation", {
    [keymaps.next_commit or "j"] = "Navigate commits",
    [keymaps.prev_commit or "k"] = "Navigate commits", 
    ["J"] = "Navigate commits (centered)",
    ["K"] = "Navigate commits (centered)",
    ["gg"] = "Go to first commit",
    ["G"] = "Go to last commit",
    ["@"] = "Go to current commit",
    ["<Up>"] = "Alternative navigation",
    ["<Down>"] = "Alternative navigation"
  })
  
  M.register_batch("actions", {
    [keymaps.show_diff or "<CR>"] = "Show diff for commit",
    ["d"] = "Show diff (alternative)",
    ["D"] = "Show diff summary/stats", 
    [keymaps.edit_message or "e"] = "Edit commit",
    ["m"] = "Set commit description",
    [keymaps.abandon or "a"] = "Abandon commit(s) - smart",
    ["A"] = "Abandon selected commits",
    [keymaps.squash or "x"] = "Squash commit (select target)",
    [keymaps.split or "s"] = "Split commit (options menu)",
    [keymaps.rebase or "r"] = "Rebase commit (options menu)",
    ["n"] = "New change (quick)",
    ["N"] = "New change (options menu)",
    ["u"] = "Undo last operation"
  })
  
  M.register_batch("selection", {
    ["<Space>"] = "Toggle commit selection",
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
    [keymaps.close or "q"] = "Close window",
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
  
  -- Menu navigation (use configured keys)
  local nav_keys = config.get('menus.navigation') or {
    next = 'j', prev = 'k', select = '<CR>', cancel = '<Esc>', cancel_alt = 'q', back = '<BS>'
  }
  
  M.register_batch("menu_navigation", {
    [nav_keys.next] = "Navigate menu items",
    [nav_keys.prev] = "Navigate menu items",
    [nav_keys.select] = "Select menu item",
    [nav_keys.cancel] = "Cancel menu",
    [nav_keys.cancel_alt] = "Cancel menu",
    [nav_keys.back] = "Go back (parent menu)"
  }, "menu")
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

return M