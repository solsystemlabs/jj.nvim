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
    "    <Up>/<Down>   Alternative navigation",
    "",
    "               ═══ Actions ═══",
    "    <CR>          Show diff for commit",
    "    d             Show diff (alternative)",
    "    D             Show diff summary/stats",
    "    e             Edit commit",
    "    m             Set commit description",
    "    a             Abandon commit(s) - smart",
    "    A             Abandon selected commits",
    "    x             Squash commit (select target)",
    "    v             Split commit (options menu)",
    "    r             Rebase commit (options menu)",
    "    n             New change (quick)",
    "    N             New change (options menu)",
    "    u             Undo last operation",
    "",
    "              ═══ Selection ═══",
    "    <Space>       Toggle commit selection",
    "    s             Show selection status",
    "    <Esc>         Clear selections or close",
    "    <Tab>         Toggle description expansion",
    "",
    "            ═══ Git Operations ═══",
    "    f             Fetch from remote",
    "    p             Push to remote",
    "    S             Show repository status",
    "    c             Quick commit working copy",
    "    C             Commit with options menu",
    "",
    "             ═══ Bookmarks ═══",
    "    b             Bookmark operations menu",
    "      c           Create bookmark here",
    "      d           Delete bookmark",
    "      m           Move bookmark here", 
    "      r           Rename bookmark",
    "      l           List bookmarks",
    "      t           Toggle bookmark filter",
    "",
    "              ═══ Revsets ═══",
    "    rs            Show revset preset menu",
    "    rr            Enter custom revset",
    "",
    "            ═══ Window Controls ═══",
    "    q             Close window",
    "    R             Refresh commits",
    "    +/-           Adjust width (large)",
    "    =/_           Adjust width (small)",
    "",
    "             ═══ Target Selection ═══",
    "    <CR>          Confirm target selection",
    "    <Esc>         Cancel target selection",
    "    b             Show bookmark selection (squash)",
    "",
    "           ═══ Multi-Select Mode ═══",
    "    <Space>       Toggle commit selection",
    "    <CR>          Confirm selection & merge",
    "    <Esc>         Cancel multi-selection",
    "",
    "             ═══ Menu Navigation ═══",
    "    j/k           Navigate menu items",
    "    <CR>          Select menu item",
    "    <Esc>/q       Cancel menu",
    "    <BS>          Go back (parent menu)",
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
  
  -- Close help dialog
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.close() end, opts)
  vim.keymap.set('n', '?', function() M.close() end, opts)
  
  -- Add scroll navigation if content is larger than window
  if content_height > window_height then
    -- Calculate scroll bounds (allow 1-2 lines past end)
    local max_top_line = math.max(content_height - window_height + 2, 1)
    
    -- Bounded scroll down (one line at a time)
    vim.keymap.set('n', 'j', function()
      local current_line = vim.fn.line('w0', win_id)  -- Get top line of window
      if current_line < max_top_line then
        vim.api.nvim_win_call(win_id, function()
          vim.cmd('normal! j')
        end)
      end
    end, opts)
    
    vim.keymap.set('n', '<Down>', function()
      local current_line = vim.fn.line('w0', win_id)  -- Get top line of window  
      if current_line < max_top_line then
        vim.api.nvim_win_call(win_id, function()
          vim.cmd('normal! j')
        end)
      end
    end, opts)
    
    -- Bounded scroll up (one line at a time)
    vim.keymap.set('n', 'k', function()
      local current_line = vim.fn.line('w0', win_id)  -- Get top line of window
      if current_line > 1 then
        vim.api.nvim_win_call(win_id, function()
          vim.cmd('normal! k')
        end)
      end
    end, opts)
    
    vim.keymap.set('n', '<Up>', function()
      local current_line = vim.fn.line('w0', win_id)  -- Get top line of window
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
      vim.api.nvim_win_set_cursor(win_id, {target_top, 0})
    end, opts)
    
    vim.keymap.set('n', '<C-b>', function()
      local current_top = vim.fn.line('w0', win_id)
      local target_top = math.max(current_top - window_height, 1)
      vim.api.nvim_win_set_cursor(win_id, {target_top, 0})
    end, opts)
    
    -- Go to bounds
    vim.keymap.set('n', 'gg', function()
      vim.api.nvim_win_set_cursor(win_id, {1, 0})
    end, opts)
    
    vim.keymap.set('n', 'G', function()
      vim.api.nvim_win_set_cursor(win_id, {content_height, 0})
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

return M