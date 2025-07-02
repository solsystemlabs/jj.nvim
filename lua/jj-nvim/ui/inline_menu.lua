local M = {}

local config = require('jj-nvim.config')
local themes = require('jj-nvim.ui.themes')
local keymap_registry = require('jj-nvim.utils.keymap_registry')

-- Menu state
M.state = {
  active = false,
  menu_id = nil,
  buf_id = nil,
  win_id = nil,
  parent_win_id = nil,
  menu_config = nil,
  selected_index = 1,
  on_select = nil,
  on_cancel = nil,
}

-- Setup highlight groups for menu styling
local function setup_menu_highlights()
  -- Define highlight groups
  vim.api.nvim_set_hl(0, 'JJMenuTitle', { fg = '#61AFEF', bold = true })        -- Bright cyan, bold
  vim.api.nvim_set_hl(0, 'JJMenuKey', { fg = '#E5C07B', bold = true })         -- Bright yellow, bold  
  vim.api.nvim_set_hl(0, 'JJMenuDescription', { fg = '#ABB2BF' })              -- Medium gray
  vim.api.nvim_set_hl(0, 'JJMenuSelected', { fg = '#FFFFFF', bg = '#3E4452', bold = true }) -- White on dark gray
  vim.api.nvim_set_hl(0, 'JJMenuBorder', { fg = '#5C6370' })                   -- Dim gray
end

-- Create a floating window for the menu
local function create_menu_window(parent_win_id, menu_config)
  local parent_width = vim.api.nvim_win_get_width(parent_win_id)
  local parent_height = vim.api.nvim_win_get_height(parent_win_id)
  
  -- Get the parent window's position in editor coordinates
  local parent_pos = vim.api.nvim_win_get_position(parent_win_id)
  local parent_row = parent_pos[1]
  local parent_col = parent_pos[2]
  
  -- Calculate menu dimensions - account for gutter columns and border
  local effective_width = parent_width - 4  -- Account for left gutter + right padding + border space
  local menu_width = math.min(50, effective_width)  -- Reduced max width and use effective width
  local menu_height = math.min(#menu_config.items + 4, parent_height - 4) -- +4 for border and title
  
  -- Center the menu within the parent window's bounds
  local row = parent_row + math.floor((parent_height - menu_height) / 2)
  local col = parent_col + math.floor((parent_width - menu_width) / 2)
  
  -- Create buffer
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'filetype', 'jj-menu')
  
  -- Window configuration - use editor positioning since parent is a split, not floating
  local win_config = {
    relative = 'editor',
    width = menu_width,
    height = menu_height,
    row = row,
    col = col,
    border = 'single',
    style = 'minimal',
    focusable = true,
    zindex = 1000,
  }
  
  -- Create window and explicitly focus it
  local win_id = vim.api.nvim_open_win(buf_id, true, win_config)
  
  -- Ensure window and buffer are focused
  vim.api.nvim_set_current_win(win_id)
  vim.api.nvim_set_current_buf(buf_id)
  
  -- Set window options
  vim.api.nvim_win_set_option(win_id, 'winhl', 'Normal:Normal,FloatBorder:JJMenuBorder')
  vim.api.nvim_win_set_option(win_id, 'wrap', true)
  vim.api.nvim_win_set_option(win_id, 'cursorline', true)
  
  return buf_id, win_id
end

-- Render the menu content
local function render_menu(buf_id, menu_config, selected_index)
  local lines = {}
  
  -- Title line (plain text)
  table.insert(lines, menu_config.title)
  table.insert(lines, "") -- Empty line after title
  
  -- Menu items (plain text)
  for i, item in ipairs(menu_config.items) do
    local line
    if i == selected_index then
      line = "▶ " .. item.key .. "  " .. item.description
    else
      line = "  " .. item.key .. "  " .. item.description
    end
    table.insert(lines, line)
  end
  
  -- Temporarily make buffer modifiable to update content
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  
  -- Apply syntax highlighting using extmarks
  local ns_id = vim.api.nvim_create_namespace('jj_menu_highlight')
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)
  
  -- Highlight title
  vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuTitle', 0, 0, -1)
  
  -- Highlight menu items
  for i, item in ipairs(menu_config.items) do
    local line_idx = i + 1 -- +1 for title, +1 for empty line, -1 for 0-based indexing
    local line_text = lines[line_idx + 1]
    
    if i == selected_index then
      -- Highlight entire selected line
      vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuSelected', line_idx, 0, -1)
    else
      -- Highlight key and description separately
      local key_start = 2 -- After "  "
      local key_end = key_start + #item.key
      local desc_start = key_end + 2 -- After key + "  "
      
      vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuKey', line_idx, key_start, key_end)
      vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuDescription', line_idx, desc_start, -1)
    end
  end
  
  -- Position cursor on selected item (accounting for title and empty line)
  vim.api.nvim_win_set_cursor(M.state.win_id, {selected_index + 2, 0})
end

-- Setup menu keymaps
local function setup_menu_keymaps(buf_id, menu_config)
  local opts = { buffer = buf_id, noremap = true, silent = true }
  
  -- Store keymap IDs for cleanup
  M.state.menu_keymaps = {}
  
  -- Get menu navigation keybinds from config
  local nav_keys = config.get('menus.navigation') or {
    next = 'j',
    prev = 'k',
    next_alt = '<Down>',
    prev_alt = '<Up>',
    select = '<CR>',
    cancel = '<Esc>',
    cancel_alt = 'q',
    back = '<BS>'
  }
  
  -- Navigation keymaps - use more unique function definitions to avoid conflicts
  local function menu_nav_down()
    if M.state.active and vim.api.nvim_get_current_buf() == buf_id then
      M.state.selected_index = math.min(M.state.selected_index + 1, #menu_config.items)
      render_menu(buf_id, menu_config, M.state.selected_index)
    end
  end
  
  local function menu_nav_up()
    if M.state.active and vim.api.nvim_get_current_buf() == buf_id then
      M.state.selected_index = math.max(M.state.selected_index - 1, 1)
      render_menu(buf_id, menu_config, M.state.selected_index)
    end
  end
  
  -- Clear any existing navigation keymaps first (including old defaults)
  local possible_nav_keys = {'j', 'k', 'h', 'l', '<Down>', '<Up>', '<Left>', '<Right>'}
  for _, key in ipairs(possible_nav_keys) do
    pcall(vim.keymap.del, 'n', key, { buffer = buf_id })
  end
  
  -- Also clear the specific configured keys
  pcall(vim.keymap.del, 'n', nav_keys.next, { buffer = buf_id })
  pcall(vim.keymap.del, 'n', nav_keys.prev, { buffer = buf_id })
  pcall(vim.keymap.del, 'n', nav_keys.next_alt, { buffer = buf_id })
  pcall(vim.keymap.del, 'n', nav_keys.prev_alt, { buffer = buf_id })
  
  -- Set navigation keymaps using configured keys
  vim.keymap.set('n', nav_keys.next, menu_nav_down, opts)
  vim.keymap.set('n', nav_keys.prev, menu_nav_up, opts)
  vim.keymap.set('n', nav_keys.next_alt, menu_nav_down, opts)
  vim.keymap.set('n', nav_keys.prev_alt, menu_nav_up, opts)
  
  -- Selection keymaps using configured keys
  vim.keymap.set('n', nav_keys.select, function()
    local selected_item = menu_config.items[M.state.selected_index]
    local callback = M.state.on_select
    M.close()
    if callback and selected_item then
      callback(selected_item)
    end
  end, opts)
  
  -- Direct key selection
  for i, item in ipairs(menu_config.items) do
    vim.keymap.set('n', item.key, function()
      local callback = M.state.on_select
      -- For toggle actions, don't close the menu immediately
      -- The callback will handle re-showing the menu
      if item.action == "toggle_filter" then
        if callback then
          callback(item)
        end
      else
        M.close()
        if callback then
          callback(item)
        end
      end
    end, opts)
  end
  
  -- Special toggle key for bookmark menus
  if menu_config.toggle_data then
    vim.keymap.set('n', 't', function()
      local callback = M.state.on_select
      if callback then
        local toggle_item = {
          action = "toggle_filter",
          data = menu_config.toggle_data
        }
        callback(toggle_item)
      end
    end, opts)
  end
  
  -- Cancel keymaps using configured keys
  vim.keymap.set('n', nav_keys.cancel, function()
    M.close()
    if M.state.on_cancel then
      M.state.on_cancel()
    end
  end, opts)
  
  vim.keymap.set('n', nav_keys.cancel_alt, function()
    M.close()
    if M.state.on_cancel then
      M.state.on_cancel()
    end
  end, opts)
  
  vim.keymap.set('n', nav_keys.back, function()
    -- Store callbacks before closing (since close() clears state)
    local parent_callback = M.state.parent_menu_callback
    local cancel_callback = M.state.on_cancel
    
    M.close()
    
    -- Schedule callbacks to run after menu is fully closed
    vim.schedule(function()
      if parent_callback then
        parent_callback()
      elseif cancel_callback then
        cancel_callback()
      end
    end)
  end, opts)
  
  -- Block all other keys to prevent conflicts with other plugins
  -- Create a list of allowed keys (use configured navigation keys)
  local allowed_keys = {
    nav_keys.next, nav_keys.prev, nav_keys.next_alt, nav_keys.prev_alt,
    nav_keys.select, nav_keys.cancel, nav_keys.cancel_alt, nav_keys.back
  }
  
  -- Add menu item keys to allowed list
  for _, item in ipairs(menu_config.items) do
    table.insert(allowed_keys, item.key)
  end
  
  -- Add toggle key if present
  if menu_config.toggle_data then
    table.insert(allowed_keys, 't')
  end
  
  -- Block all printable ASCII chars and common keys that aren't in our allowed list
  local all_keys = {}
  
  -- Add letters a-z (excluding allowed ones)
  for i = string.byte('a'), string.byte('z') do
    local key = string.char(i)
    if not vim.tbl_contains(allowed_keys, key) then
      table.insert(all_keys, key)
    end
  end
  
  -- Add numbers 0-9 (excluding allowed ones)
  for i = string.byte('0'), string.byte('9') do
    local key = string.char(i)
    if not vim.tbl_contains(allowed_keys, key) then
      table.insert(all_keys, key)
    end
  end
  
  -- Add common special keys (excluding allowed ones)
  local special_keys = {
    '<Space>', '<Tab>', '<S-Tab>', '<C-c>', '<C-d>', '<C-u>', '<C-f>', '<C-b>',
    '<PageUp>', '<PageDown>', '<Home>', '<End>', '<Left>', '<Right>',
    '<C-w>', '<C-o>', '<C-i>', '<C-r>', '<C-z>', '<C-x>', '<C-v>',
    '<F1>', '<F2>', '<F3>', '<F4>', '<F5>', '<F6>', '<F7>', '<F8>', '<F9>', '<F10>', '<F11>', '<F12>',
    ':', ';', '/', '?', '.', ',', '<', '>', '[', ']', '{', '}', '(', ')', '=', '+', '-', '_',
    '!', '@', '#', '$', '%', '^', '&', '*', '|', '\\', '~', '`', '"', "'"
  }
  
  for _, key in ipairs(special_keys) do
    if not vim.tbl_contains(allowed_keys, key) then
      table.insert(all_keys, key)
    end
  end
  
  -- Set no-op keymaps for all blocked keys
  for _, key in ipairs(all_keys) do
    vim.keymap.set('n', key, function() end, opts)
  end
end

-- Show the inline menu
M.show = function(parent_win_id, menu_config, callbacks)
  -- Close any existing menu
  if M.state.active then
    M.close()
  end
  
  -- Validate menu configuration
  if not menu_config or not menu_config.items or #menu_config.items == 0 then
    vim.notify("Invalid menu configuration", vim.log.levels.WARN)
    return false
  end
  
  -- Register menu items with keymap registry for help generation
  if menu_config.id then
    keymap_registry.register_menu_items(menu_config.id, menu_config.items)
  end
  
  -- Setup highlight groups
  setup_menu_highlights()
  
  -- Create menu window
  local buf_id, win_id = create_menu_window(parent_win_id, menu_config)
  
  -- Update state
  M.state.active = true
  M.state.menu_id = menu_config.id or "default"
  M.state.buf_id = buf_id
  M.state.win_id = win_id
  M.state.parent_win_id = parent_win_id
  M.state.menu_config = menu_config
  M.state.selected_index = 1
  M.state.on_select = callbacks and callbacks.on_select
  M.state.on_cancel = callbacks and callbacks.on_cancel
  M.state.parent_menu_callback = callbacks and callbacks.parent_menu_callback
  
  -- Setup keymaps
  setup_menu_keymaps(buf_id, menu_config)
  
  -- Render menu
  render_menu(buf_id, menu_config, M.state.selected_index)
  
  -- Auto-close on focus loss
  vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
    buffer = buf_id,
    callback = function()
      vim.schedule(function()
        if M.state.active then
          M.close()
          if M.state.on_cancel then
            M.state.on_cancel()
          end
        end
      end)
    end,
    once = true,
  })
  
  return true
end

-- Close the menu
M.close = function()
  if not M.state.active then
    return
  end
  
  -- Close window and buffer
  if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
    vim.api.nvim_win_close(M.state.win_id, true)
  end
  
  if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
    vim.api.nvim_buf_delete(M.state.buf_id, { force = true })
  end
  
  -- Return focus to parent window (with error protection)
  if M.state.parent_win_id and vim.api.nvim_win_is_valid(M.state.parent_win_id) then
    pcall(vim.api.nvim_set_current_win, M.state.parent_win_id)
  end
  
  -- Reset state
  M.state = {
    active = false,
    menu_id = nil,
    buf_id = nil,
    win_id = nil,
    parent_win_id = nil,
    menu_config = nil,
    selected_index = 1,
    on_select = nil,
    on_cancel = nil,
  }
end

-- Check if menu is currently active
M.is_active = function()
  return M.state.active
end

-- Get current menu state
M.get_state = function()
  return vim.deepcopy(M.state)
end

return M