local M = {}

local config = require('jj-nvim.config')
local buffer = require('jj-nvim.ui.buffer')
local navigation = require('jj-nvim.ui.navigation')

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
  
  -- Set up commit highlighting
  M.setup_commit_highlighting()
  
  M.setup_keymaps()
end

-- Open window with an existing buffer (for commit-based system)
M.open_with_buffer = function(buf_id)
  if M.is_open() then
    return
  end

  local width = config.get('window.width')
  local position = config.get('window.position')
  
  local win_width = vim.api.nvim_get_option('columns')
  local win_height = vim.api.nvim_get_option('lines')
  
  local col = position == 'left' and 0 or (win_width - width)
  
  state.buf_id = buf_id
  
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
  
  -- Set up commit highlighting
  M.setup_commit_highlighting()
  
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
  
  -- Basic window controls
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.close() end, opts)
  
  -- Smart commit navigation (replaces basic j/k)
  vim.keymap.set('n', 'j', function() 
    navigation.next_commit(state.win_id)
  end, opts)
  vim.keymap.set('n', 'k', function() 
    navigation.prev_commit(state.win_id)
  end, opts)
  
  -- Additional navigation
  vim.keymap.set('n', 'J', function() 
    navigation.next_commit_centered(state.win_id)
  end, opts)
  vim.keymap.set('n', 'K', function() 
    navigation.prev_commit_centered(state.win_id)
  end, opts)
  
  -- Go to specific commits
  vim.keymap.set('n', 'gg', function() 
    navigation.goto_first_commit(state.win_id)
  end, opts)
  vim.keymap.set('n', 'G', function() 
    navigation.goto_last_commit(state.win_id)
  end, opts)
  vim.keymap.set('n', '@', function() 
    navigation.goto_current_commit(state.win_id)
  end, opts)
  
  -- Snap to commit header if cursor is on a description line
  vim.keymap.set('n', '<Space>', function() 
    navigation.snap_to_commit_header(state.win_id)
  end, opts)
  
  -- Actions on commits
  vim.keymap.set('n', '<CR>', function()
    local commit = navigation.get_current_commit(state.win_id)
    if commit then
      vim.notify(string.format("Selected commit: %s (%s)", 
                               commit.short_change_id, 
                               commit:get_short_description()), vim.log.levels.INFO)
      -- TODO: Implement diff preview
    else
      vim.notify("No commit selected", vim.log.levels.WARN)
    end
  end, opts)
  
  -- Buffer refresh
  vim.keymap.set('n', 'R', function()
    vim.notify("Refreshing commits...", vim.log.levels.INFO)
    buffer.refresh(state.buf_id)
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
  
  -- Refresh buffer content to apply new wrapping
  buffer.refresh(state.buf_id)
  
  vim.notify(string.format("Window width: %d", new_width), vim.log.levels.INFO)
end

-- Set up commit highlighting system
M.setup_commit_highlighting = function()
  if not state.buf_id or not state.win_id then return end
  
  -- Create highlight namespace for commit highlighting
  local ns_id = vim.api.nvim_create_namespace('jj_commit_highlight')
  
  -- Define highlight group for selected commit
  vim.api.nvim_set_hl(0, 'JJCommitSelected', { bg = '#3c3836' }) -- Dark background for selection
  
  -- Function to highlight the current commit
  local function highlight_current_commit()
    if not state.win_id or not vim.api.nvim_win_is_valid(state.win_id) then return end
    
    -- Clear previous highlighting
    vim.api.nvim_buf_clear_namespace(state.buf_id, ns_id, 0, -1)
    
    -- Get current cursor position
    local cursor = vim.api.nvim_win_get_cursor(state.win_id)
    local line_number = cursor[1]
    
    -- Get the commit at this line
    local commit = buffer.get_commit_at_line(line_number)
    if not commit then return end
    
    -- Highlight all lines belonging to this commit
    if commit.line_start and commit.line_end then
      for line_idx = commit.line_start, commit.line_end do
        vim.api.nvim_buf_add_highlight(state.buf_id, ns_id, 'JJCommitSelected', line_idx - 1, 0, -1)
      end
    end
  end
  
  -- Set up autocmd to highlight on cursor movement
  vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
    buffer = state.buf_id,
    callback = highlight_current_commit,
    group = vim.api.nvim_create_augroup('JJCommitHighlight_' .. state.buf_id, { clear = true })
  })
  
  -- Initial highlighting
  highlight_current_commit()
end

M.get_current_line = function()
  if not M.is_open() then return nil end
  local line_nr = vim.api.nvim_win_get_cursor(state.win_id)[1]
  return vim.api.nvim_buf_get_lines(state.buf_id, line_nr - 1, line_nr, false)[1]
end

return M