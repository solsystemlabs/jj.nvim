local M = {}

local config = require('jj-nvim.config')
local buffer = require('jj-nvim.ui.buffer')

local state = {
  win_id = nil,
  buf_id = nil,
}

M.is_open = function()
  return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

M.open = function(content)
  if M.is_open() then
    return
  end

  local width = config.get('window.width')
  local position = config.get('window.position')
  
  local win_width = vim.api.nvim_get_option('columns')
  local win_height = vim.api.nvim_get_option('lines')
  
  local col = position == 'left' and 0 or (win_width - width)
  
  state.buf_id = buffer.create(content)
  
  state.win_id = vim.api.nvim_open_win(state.buf_id, true, {
    relative = 'editor',
    width = width,
    height = win_height - 2,
    col = col,
    row = 0,
    style = 'minimal',
    border = 'none',
  })
  
  vim.api.nvim_win_set_option(state.win_id, 'wrap', config.get('window.wrap'))
  vim.api.nvim_win_set_option(state.win_id, 'cursorline', true)
  vim.api.nvim_win_set_option(state.win_id, 'winhl', '')
  
  -- Ensure buffer supports colors
  vim.api.nvim_buf_set_option(state.buf_id, 'syntax', 'off')
  vim.api.nvim_set_option_value('termguicolors', true, {})
  
  M.setup_keymaps()
end

M.close = function()
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, false)
  end
  state.win_id = nil
  state.buf_id = nil
end

M.setup_keymaps = function()
  if not state.buf_id then return end
  
  local opts = { noremap = true, silent = true, buffer = state.buf_id }
  
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.close() end, opts)
  vim.keymap.set('n', 'j', 'j', opts)
  vim.keymap.set('n', 'k', 'k', opts)
  vim.keymap.set('n', '<CR>', function()
    vim.notify("Show diff not implemented yet", vim.log.levels.INFO)
  end, opts)
  
  -- Window width adjustment keybinds
  vim.keymap.set('n', '+', function() M.adjust_width(5) end, opts)
  vim.keymap.set('n', '-', function() M.adjust_width(-5) end, opts)
  vim.keymap.set('n', '=', function() M.adjust_width(1) end, opts)
  vim.keymap.set('n', '_', function() M.adjust_width(-1) end, opts)
end

M.adjust_width = function(delta)
  if not M.is_open() then return end
  
  local current_width = vim.api.nvim_win_get_width(state.win_id)
  local new_width = math.max(30, math.min(200, current_width + delta)) -- Clamp between 30-200
  
  -- Update the window width
  vim.api.nvim_win_set_width(state.win_id, new_width)
  
  -- Update the position if it's on the right side
  local position = config.get('window.position')
  if position == 'right' then
    local win_width = vim.api.nvim_get_option('columns')
    local new_col = win_width - new_width
    vim.api.nvim_win_set_config(state.win_id, {
      relative = 'editor',
      width = new_width,
      height = vim.api.nvim_win_get_height(state.win_id),
      col = new_col,
      row = 0,
    })
  else
    vim.api.nvim_win_set_config(state.win_id, {
      relative = 'editor',
      width = new_width,
      height = vim.api.nvim_win_get_height(state.win_id),
      col = 0,
      row = 0,
    })
  end
  
  -- Save the new width persistently
  config.set('window.width', new_width)
  
  vim.notify(string.format("Window width: %d", new_width), vim.log.levels.INFO)
end

M.get_current_line = function()
  if not M.is_open() then return nil end
  local line_nr = vim.api.nvim_win_get_cursor(state.win_id)[1]
  return vim.api.nvim_buf_get_lines(state.buf_id, line_nr - 1, line_nr, false)[1]
end

return M