local M = {}

local config = require('jj-nvim.config')
local keymap_registry = require('jj-nvim.utils.keymap_registry')

-- Help dialog state
local state = {
  win_id = nil,
  buf_id = nil,
  parent_win_id = nil,
}

-- Setup highlight groups for help dialog
local function setup_help_highlights()
  vim.api.nvim_set_hl(0, 'JJHelpTitle', { fg = '#61AFEF', bold = true })   -- Bright blue, bold
  vim.api.nvim_set_hl(0, 'JJHelpSection', { fg = '#E06C75', bold = true }) -- Red, bold for sections
  vim.api.nvim_set_hl(0, 'JJHelpKey', { fg = '#E5C07B', bold = true })     -- Yellow, bold for keys
  vim.api.nvim_set_hl(0, 'JJHelpDescription', { fg = '#ABB2BF' })          -- Gray for descriptions
  vim.api.nvim_set_hl(0, 'JJHelpBorder', { fg = '#5C6370' })               -- Dim gray for border
end

-- Build help content dynamically from keymap registry
local function build_help_content()
  -- Always re-initialize keymap registry to pick up any config changes
  -- This ensures help always shows current config state
  keymap_registry.initialize(config)

  local lines = {
    "           JJ-Nvim Keybind Reference",
    "",
  }

  -- Helper function to format keymap lines
  local function add_section(title, category, mode)
    mode = mode or "main"
    local keymaps = keymap_registry.get_category(category, mode)

    if next(keymaps) then
      table.insert(lines, string.format("              ═══ %s ═══", title))

      -- Sort keymaps by key for consistent display
      local sorted_keys = {}
      for key, _ in pairs(keymaps) do
        table.insert(sorted_keys, key)
      end
      table.sort(sorted_keys)

      for _, key in ipairs(sorted_keys) do
        local keymap = keymaps[key]
        local display_key = keymap_registry.format_key(key)
        table.insert(lines, string.format("    %-12s  %s", display_key, keymap.description))
      end
      table.insert(lines, "")
    end
  end

  -- Add sections for main mode
  add_section("Navigation", "navigation")
  add_section("Actions", "actions")
  add_section("Selection", "selection")
  add_section("Git Operations", "git_operations")
  add_section("Bookmarks", "bookmarks")

  -- Add bookmark submenu items if available
  local bookmark_menu = keymap_registry.get_menu_items("bookmark")
  if next(bookmark_menu) then
    local nav_keys = config.get('keybinds.menu_navigation') or config.get('menus.navigation') or {}
    local menu_keys = config.get('keybinds.menus.bookmark') or config.get('menus.bookmark') or {}

    for action, key in pairs(menu_keys) do
      local description = ""
      if action == "create" then
        description = "Create bookmark here"
      elseif action == "delete" then
        description = "Delete bookmark"
      elseif action == "move" then
        description = "Move bookmark here"
      elseif action == "rename" then
        description = "Rename bookmark"
      elseif action == "list" then
        description = "List bookmarks"
      elseif action == "toggle_filter" then
        description = "Toggle bookmark filter"
      end

      if description ~= "" then
        table.insert(lines, string.format("      %-9s  %s", key, description))
      end
    end
    table.insert(lines, "")
  end

  add_section("Revsets", "revsets")
  add_section("Window Controls", "window_controls")

  -- Special modes
  add_section("Target Selection", "target_selection", "target_selection")
  add_section("Multi-Select Mode", "multi_select", "multi_select")

  -- Menu navigation (show configured keys)
  local nav_keys = config.get('keybinds.menu_navigation') or config.get('menus.navigation') or {}
  if next(nav_keys) then
    table.insert(lines, "             ═══ Menu Navigation ═══")
    
    -- Handle backward compatibility for key names
    local next_key = nav_keys.next or 'j'
    local prev_key = nav_keys.prev or 'k'
    local jump_next = nav_keys.jump_next or nav_keys.next_alt
    local jump_prev = nav_keys.jump_prev or nav_keys.prev_alt
    
    table.insert(lines,
      string.format("    %-12s  Navigate menu items",
        keymap_registry.format_key(next_key) .. "/" .. keymap_registry.format_key(prev_key)))
    
    if jump_next and jump_prev then
      table.insert(lines,
        string.format("    %-12s  Jump navigate menu items",
          keymap_registry.format_key(jump_next) .. "/" .. keymap_registry.format_key(jump_prev)))
    end
    
    table.insert(lines,
      string.format("    %-12s  Select menu item", keymap_registry.format_key(nav_keys.select or '<CR>')))
    
    -- Handle cancel key arrays
    local cancel_keys = {}
    if type(nav_keys.cancel) == "table" then
      cancel_keys = nav_keys.cancel
    elseif nav_keys.cancel then
      table.insert(cancel_keys, nav_keys.cancel)
    end
    if nav_keys.cancel_alt then
      table.insert(cancel_keys, nav_keys.cancel_alt)
    end
    
    if #cancel_keys > 0 then
      local cancel_str = ""
      for i, key in ipairs(cancel_keys) do
        if i > 1 then cancel_str = cancel_str .. "/" end
        cancel_str = cancel_str .. keymap_registry.format_key(key)
      end
      table.insert(lines,
        string.format("    %-12s  Cancel menu", cancel_str))
    end
    
    table.insert(lines,
      string.format("    %-12s  Go back (parent menu)", keymap_registry.format_key(nav_keys.back or '<BS>')))
    table.insert(lines, "")
  end

  add_section("Help", "help")

  -- Footer - use configured cancel keys (handle arrays)
  local footer_cancel_keys = {}
  
  -- Handle cancel key arrays
  if type(nav_keys.cancel) == "table" then
    for _, key in ipairs(nav_keys.cancel) do
      table.insert(footer_cancel_keys, keymap_registry.format_key(key))
    end
  elseif nav_keys.cancel then
    table.insert(footer_cancel_keys, keymap_registry.format_key(nav_keys.cancel))
  end
  
  -- Add legacy cancel_alt if present
  if nav_keys.cancel_alt then 
    table.insert(footer_cancel_keys, keymap_registry.format_key(nav_keys.cancel_alt)) 
  end
  
  table.insert(footer_cancel_keys, "?")

  table.insert(lines, "")
  table.insert(lines, "           ═══ Help Navigation ═══")
  table.insert(lines, "    ↑/↓           Scroll help content")
  table.insert(lines, "    Ctrl+j/k      Alternative scroll")
  table.insert(lines, "    Ctrl+f/b      Page up/down")
  table.insert(lines, "    gg/G          Go to top/bottom")
  table.insert(lines, "")
  table.insert(lines, string.format("           Press %s to close", table.concat(footer_cancel_keys, ", ")))

  return lines
end

-- Apply syntax highlighting to help buffer
local function apply_help_highlighting(buf_id, lines)
  for line_nr, line in ipairs(lines) do
    local line_idx = line_nr - 1

    -- Title (first line)
    if line:match("JJ%-Nvim Keybind Reference") then
      vim.api.nvim_buf_add_highlight(buf_id, -1, 'JJHelpTitle', line_idx, 0, -1)

      -- Section headers (lines with ═══)
    elseif line:match("═══.*═══") then
      vim.api.nvim_buf_add_highlight(buf_id, -1, 'JJHelpSection', line_idx, 0, -1)

      -- Keybind lines (start with 4 spaces then key)
    elseif line:match("^    %S+") then
      -- Find where the key ends (first sequence of spaces after the key)
      local key_start = 5 -- After "    "
      local key_part = line:sub(key_start)
      local key_end_relative = key_part:find("%s+")

      if key_end_relative then
        local key_end = key_start + key_end_relative - 1
        -- Highlight the key
        vim.api.nvim_buf_add_highlight(buf_id, -1, 'JJHelpKey', line_idx, key_start - 1, key_end)
        -- Highlight the description
        vim.api.nvim_buf_add_highlight(buf_id, -1, 'JJHelpDescription', line_idx, key_end + 1, -1)
      end

      -- Help instructions (last line)
    elseif line:match("Press.*to close") then
      vim.api.nvim_buf_add_highlight(buf_id, -1, 'JJHelpDescription', line_idx, 0, -1)
    end
  end
end

-- Create help window centered in log window, or in editor if log window is too small
local function create_help_window(parent_win_id, content_lines)
  local parent_pos = vim.api.nvim_win_get_position(parent_win_id)
  local parent_width = vim.api.nvim_win_get_width(parent_win_id)
  local parent_height = vim.api.nvim_win_get_height(parent_win_id)

  -- Calculate help window dimensions
  local help_width = 50
  local content_height = #content_lines
  local min_margin = 4

  -- Calculate available height for different contexts
  local parent_available_height = parent_height - (min_margin * 2)
  local screen_available_height = vim.o.lines - (min_margin * 2)

  -- Apply 90% constraint to available height
  local max_parent_height = math.floor(parent_available_height * 0.9)
  local max_screen_height = math.floor(screen_available_height * 0.9)

  -- Determine optimal height (content height, but constrained by available space)
  local help_height = content_height
  local can_fit_in_parent = false

  if parent_width >= help_width + min_margin then
    -- Check if we can fit in parent window
    if help_height <= max_parent_height then
      can_fit_in_parent = true
    else
      -- Try to fit in parent with 90% height constraint
      help_height = max_parent_height
      can_fit_in_parent = true
    end
  end

  -- If can't fit in parent, use screen space with 90% constraint
  if not can_fit_in_parent then
    help_height = math.min(content_height, max_screen_height)
  end

  local col, row, relative, win_ref

  if can_fit_in_parent then
    -- Center within the log window
    col = math.floor((parent_width - help_width) / 2)
    row = math.floor((parent_height - help_height) / 2)
    relative = 'win'
    win_ref = parent_win_id
  else
    -- Center within the entire Neovim window
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines
    col = math.floor((screen_width - help_width) / 2)
    row = math.floor((screen_height - help_height) / 2)
    relative = 'editor'
    win_ref = nil
  end

  -- Create buffer
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf_id, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf_id, 'filetype', 'jj-help')

  -- Window configuration
  local win_config = {
    relative = relative,
    width = help_width,
    height = help_height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    zindex = 100,
  }

  -- Add win reference if centering within log window
  if win_ref then
    win_config.win = win_ref
  end

  -- Create window and focus it
  local win_id = vim.api.nvim_open_win(buf_id, true, win_config)

  -- Set window options
  vim.api.nvim_win_set_option(win_id, 'wrap', false)
  vim.api.nvim_win_set_option(win_id, 'cursorline', false)
  vim.api.nvim_win_set_option(win_id, 'number', false)
  vim.api.nvim_win_set_option(win_id, 'relativenumber', false)
  vim.api.nvim_win_set_option(win_id, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(win_id, 'scrolloff', 0)

  -- Enable scrolling if content is larger than window
  if content_height > help_height then
    vim.api.nvim_win_set_option(win_id, 'wrap', false)
    vim.api.nvim_win_set_option(win_id, 'scrollbind', false)
  end

  return win_id, buf_id, help_height
end

-- Setup keymaps for help dialog
local function setup_help_keymaps(buf_id, win_id, content_height, window_height)
  local opts = { noremap = true, silent = true, buffer = buf_id }

  -- Get configured navigation keys to avoid conflicts
  local nav_keys = config.get('keybinds.menu_navigation') or config.get('menus.navigation') or {
    next = 'j', prev = 'k', cancel = {'<Esc>', 'q'}
  }

  -- Close help dialog using configured keys (handle arrays)
  local cancel_keys = {}
  if type(nav_keys.cancel) == "table" then
    cancel_keys = nav_keys.cancel
  elseif nav_keys.cancel then
    table.insert(cancel_keys, nav_keys.cancel)
  end
  if nav_keys.cancel_alt then
    table.insert(cancel_keys, nav_keys.cancel_alt)
  end
  
  -- Set up close keymaps for all cancel keys
  for _, cancel_key in ipairs(cancel_keys) do
    vim.keymap.set('n', cancel_key, function() M.close() end, opts)
  end
  vim.keymap.set('n', '?', function() M.close() end, opts)

  -- Add scroll navigation if content is larger than window
  if content_height > window_height then
    -- Calculate scroll bounds (allow 1-2 lines past end)
    local max_top_line = math.max(content_height - window_height + 2, 1)

    -- Use different keys for help scrolling to avoid conflicts with menu navigation
    -- Use arrow keys and Ctrl+j/k for scrolling instead of j/k
    vim.keymap.set('n', '<Down>', function()
      local current_line = vim.fn.line('w0', win_id) -- Get top line of window
      if current_line < max_top_line then
        vim.api.nvim_win_call(win_id, function()
          vim.cmd('normal! j')
        end)
      end
    end, opts)

    vim.keymap.set('n', '<Up>', function()
      local current_line = vim.fn.line('w0', win_id) -- Get top line of window
      if current_line > 1 then
        vim.api.nvim_win_call(win_id, function()
          vim.cmd('normal! k')
        end)
      end
    end, opts)

    -- Alternative scroll keys that won't conflict
    vim.keymap.set('n', '<C-j>', function()
      local current_line = vim.fn.line('w0', win_id) -- Get top line of window
      if current_line < max_top_line then
        vim.api.nvim_win_call(win_id, function()
          vim.cmd('normal! j')
        end)
      end
    end, opts)

    vim.keymap.set('n', '<C-k>', function()
      local current_line = vim.fn.line('w0', win_id) -- Get top line of window
      if current_line > 1 then
        vim.api.nvim_win_call(win_id, function()
          vim.cmd('normal! k')
        end)
      end
    end, opts)

    -- Page navigation with bounds
    vim.keymap.set('n', '<C-f>', function()
      local current_top = vim.fn.line('w0', win_id)
      local target_top = math.min(current_top + window_height, max_top_line)
      vim.api.nvim_win_set_cursor(win_id, { target_top, 0 })
    end, opts)

    vim.keymap.set('n', '<C-b>', function()
      local current_top = vim.fn.line('w0', win_id)
      local target_top = math.max(current_top - window_height, 1)
      vim.api.nvim_win_set_cursor(win_id, { target_top, 0 })
    end, opts)

    -- Go to bounds
    vim.keymap.set('n', 'gg', function()
      vim.api.nvim_win_set_cursor(win_id, { 1, 0 })
    end, opts)

    vim.keymap.set('n', 'G', function()
      vim.api.nvim_win_set_cursor(win_id, { content_height, 0 })
    end, opts)
  end
end

-- Show help dialog
M.show = function(parent_win_id)
  if M.is_open() then
    M.close()
    return
  end

  -- Setup highlighting
  setup_help_highlights()

  -- Build content first to calculate proper window size
  local lines = build_help_content()

  -- Create window and buffer with content-aware sizing
  local win_id, buf_id, window_height = create_help_window(parent_win_id, lines)

  -- Set content
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)

  -- Apply syntax highlighting
  apply_help_highlighting(buf_id, lines)

  -- Setup keymaps with scroll support
  setup_help_keymaps(buf_id, win_id, #lines, window_height)

  -- Store state
  state.win_id = win_id
  state.buf_id = buf_id
  state.parent_win_id = parent_win_id
end

-- Close help dialog
M.close = function()
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, false)
  end

  -- Clear state
  state.win_id = nil
  state.buf_id = nil
  state.parent_win_id = nil
end

-- Check if help dialog is open
M.is_open = function()
  return state.win_id and vim.api.nvim_win_is_valid(state.win_id)
end

-- Get current help state (for debugging)
M.get_state = function()
  return {
    win_id = state.win_id,
    buf_id = state.buf_id,
    parent_win_id = state.parent_win_id
  }
end

return M

