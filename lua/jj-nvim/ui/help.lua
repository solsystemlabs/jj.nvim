local M = {}

local config = require('jj-nvim.config')

-- Help dialog state
local state = {
  win_id = nil,
  buf_id = nil,
  parent_win_id = nil,
}

-- Setup highlight groups for help dialog
local function setup_help_highlights()
  vim.api.nvim_set_hl(0, 'JJHelpTitle', { fg = '#61AFEF', bold = true })        -- Bright blue, bold
  vim.api.nvim_set_hl(0, 'JJHelpSection', { fg = '#E06C75', bold = true })     -- Red, bold for sections
  vim.api.nvim_set_hl(0, 'JJHelpKey', { fg = '#E5C07B', bold = true })         -- Yellow, bold for keys
  vim.api.nvim_set_hl(0, 'JJHelpDescription', { fg = '#ABB2BF' })              -- Gray for descriptions
  vim.api.nvim_set_hl(0, 'JJHelpBorder', { fg = '#5C6370' })                   -- Dim gray for border
end

-- Build help content with keybind information
local function build_help_content()
  local lines = {
    "           JJ-Nvim Keybind Reference",
    "",
    "              ═══ Navigation ═══",
    "    j/k           Navigate commits",
    "    J/K           Navigate commits (centered)",
    "    gg            Go to first commit",
    "    G             Go to last commit", 
    "    @             Go to current commit",
    "",
    "               ═══ Actions ═══",
    "    <CR>          Show diff for commit",
    "    d             Show diff (alternative)",
    "    D             Show diff summary/stats",
    "    e             Edit commit",
    "    a             Abandon commit(s)",
    "    A             Abandon selected commits",
    "    n             New change menu",
    "",
    "              ═══ Selection ═══",
    "    <Space>       Toggle commit selection",
    "    s             Show selection status",
    "    <Esc>         Clear selections",
    "    <Tab>         Toggle description expansion",
    "",
    "            ═══ Git Operations ═══",
    "    f             Fetch from remote",
    "    p             Push to remote",
    "",
    "            ═══ Window Controls ═══",
    "    q             Close window",
    "    R             Refresh commits",
    "    +/-           Adjust width (large)",
    "    =/_           Adjust width (small)",
    "",
    "                ═══ Help ═══",
    "    ?             Show/hide this help",
    "",
    "           Press q, <Esc>, or ? to close"
  }
  
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
      local key_start = 5  -- After "    "
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
local function create_help_window(parent_win_id)
  local parent_pos = vim.api.nvim_win_get_position(parent_win_id)
  local parent_width = vim.api.nvim_win_get_width(parent_win_id)
  local parent_height = vim.api.nvim_win_get_height(parent_win_id)
  
  -- Calculate help window dimensions
  local help_width = 50
  local help_height = 40
  
  -- Check if help dialog can fit within the log window (with margins)
  local min_margin = 4
  local can_fit_in_parent = (parent_width >= help_width + min_margin) and 
                           (parent_height >= help_height + min_margin)
  
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
  
  return win_id, buf_id
end

-- Setup keymaps for help dialog
local function setup_help_keymaps(buf_id, win_id)
  local opts = { noremap = true, silent = true, buffer = buf_id }
  
  -- Close help dialog
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.close() end, opts)
  vim.keymap.set('n', '?', function() M.close() end, opts)
end

-- Show help dialog
M.show = function(parent_win_id)
  if M.is_open() then
    M.close()
    return
  end
  
  -- Setup highlighting
  setup_help_highlights()
  
  -- Create window and buffer
  local win_id, buf_id = create_help_window(parent_win_id)
  
  -- Build and set content
  local lines = build_help_content()
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  
  -- Apply syntax highlighting
  apply_help_highlighting(buf_id, lines)
  
  -- Setup keymaps
  setup_help_keymaps(buf_id, win_id)
  
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

return M