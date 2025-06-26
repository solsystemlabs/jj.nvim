local M = {}

local config = require('jj-nvim.config')
local themes = require('jj-nvim.ui.themes')

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
  
  -- Calculate menu dimensions
  local menu_width = math.min(60, parent_width - 4)
  local menu_height = math.min(#menu_config.items + 4, parent_height - 4) -- +4 for border and title
  
  -- Center the menu in the parent window
  local row = math.floor((parent_height - menu_height) / 2)
  local col = math.floor((parent_width - menu_width) / 2)
  
  -- Create buffer
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'filetype', 'jj-menu')
  
  -- Window configuration
  local win_config = {
    relative = 'win',
    win = parent_win_id,
    width = menu_width,
    height = menu_height,
    row = row,
    col = col,
    border = 'single',
    style = 'minimal',
    focusable = true,
    zindex = 1000,
  }
  
  -- Create window
  local win_id = vim.api.nvim_open_win(buf_id, true, win_config)
  
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
  
  -- Navigation keymaps
  vim.keymap.set('n', 'j', function()
    M.state.selected_index = math.min(M.state.selected_index + 1, #menu_config.items)
    render_menu(buf_id, menu_config, M.state.selected_index)
  end, opts)
  
  vim.keymap.set('n', 'k', function()
    M.state.selected_index = math.max(M.state.selected_index - 1, 1)
    render_menu(buf_id, menu_config, M.state.selected_index)
  end, opts)
  
  vim.keymap.set('n', '<Down>', function()
    M.state.selected_index = math.min(M.state.selected_index + 1, #menu_config.items)
    render_menu(buf_id, menu_config, M.state.selected_index)
  end, opts)
  
  vim.keymap.set('n', '<Up>', function()
    M.state.selected_index = math.max(M.state.selected_index - 1, 1)
    render_menu(buf_id, menu_config, M.state.selected_index)
  end, opts)
  
  -- Selection keymaps
  vim.keymap.set('n', '<CR>', function()
    local selected_item = menu_config.items[M.state.selected_index]
    M.close()
    if M.state.on_select then
      M.state.on_select(selected_item)
    end
  end, opts)
  
  -- Direct key selection
  for i, item in ipairs(menu_config.items) do
    vim.keymap.set('n', item.key, function()
      M.close()
      if M.state.on_select then
        M.state.on_select(item)
      end
    end, opts)
  end
  
  -- Cancel keymaps
  vim.keymap.set('n', '<Esc>', function()
    M.close()
    if M.state.on_cancel then
      M.state.on_cancel()
    end
  end, opts)
  
  vim.keymap.set('n', 'q', function()
    M.close()
    if M.state.on_cancel then
      M.state.on_cancel()
    end
  end, opts)
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
  
  -- Return focus to parent window
  if M.state.parent_win_id and vim.api.nvim_win_is_valid(M.state.parent_win_id) then
    vim.api.nvim_set_current_win(M.state.parent_win_id)
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