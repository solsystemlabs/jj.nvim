local M = {}

local config = require('jj-nvim.config')
local ansi = require('jj-nvim.utils.ansi')

-- Create buffer with ANSI color processing
-- Extracted from actions.lua create_diff_buffer and create_status_buffer
M.create_buffer_with_ansi = function(content, buffer_name, filetype, options)
  options = options or {}
  
  -- Create a new buffer
  local buf_id = vim.api.nvim_create_buf(false, true)

  -- Set buffer name (make it unique using buffer ID if needed)
  local unique_name = options.unique_name and string.format('%s-%s', buffer_name, buf_id) or buffer_name
  vim.api.nvim_buf_set_name(buf_id, unique_name)

  -- Configure buffer options
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', false)
  vim.api.nvim_buf_set_option(buf_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'swapfile', false)

  -- Set filetype for syntax highlighting
  if filetype then
    vim.api.nvim_buf_set_option(buf_id, 'filetype', filetype)
  end

  -- Setup ANSI highlights
  ansi.setup_highlights()

  -- Process content for ANSI colors and set buffer content
  local lines = vim.split(content, '\n', { plain = true })
  local clean_lines = {}
  local highlights = {}

  -- Check if content has ANSI codes
  local has_ansi = false
  for _, line in ipairs(lines) do
    if line:find('\27%[') then
      has_ansi = true
      break
    end
  end

  if has_ansi then
    -- Process ANSI colors
    for line_nr, line in ipairs(lines) do
      local segments = ansi.parse_ansi_line(line)
      local clean_line = ansi.strip_ansi(line)

      table.insert(clean_lines, clean_line)

      local col = 0
      for _, segment in ipairs(segments) do
        if segment.highlight and segment.text ~= '' then
          table.insert(highlights, {
            line = line_nr - 1,
            col_start = col,
            col_end = col + #segment.text,
            hl_group = segment.highlight
          })
        end
        col = col + #segment.text
      end
    end
  else
    clean_lines = lines
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, clean_lines)

  -- Apply ANSI color highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf_id, -1, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end

  -- Make buffer readonly after setting content
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', true)

  return buf_id
end

-- Create floating window configuration
-- Extracted from actions.lua create_float_config
M.create_float_config = function(config_key, options)
  options = options or {}
  config_key = config_key or 'diff.float'
  
  local float_config = config.get(config_key) or {}
  local width_ratio = float_config.width or options.width or 0.8
  local height_ratio = float_config.height or options.height or 0.8
  local border = float_config.border or options.border or 'rounded'

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  local width = math.floor(screen_width * width_ratio)
  local height = math.floor(screen_height * height_ratio)
  local col = math.floor((screen_width - width) / 2)
  local row = math.floor((screen_height - height) / 2)

  return {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = border,
    zindex = options.zindex or 100,
  }
end

-- Display buffer in a split window
-- Extracted from actions.lua display_diff_buffer_split
M.display_buffer_split = function(buf_id, split_direction, options)
  options = options or {}
  split_direction = split_direction or 'horizontal'

  -- Get current window to return focus later if needed
  local current_win = vim.api.nvim_get_current_win()

  -- Create split window
  if split_direction == 'vertical' then
    vim.cmd('vsplit')
  else
    vim.cmd('split')
  end

  -- Switch to the new buffer
  vim.api.nvim_win_set_buf(0, buf_id)

  local win_id = vim.api.nvim_get_current_win()
  
  -- Set window options if specified
  if options.wrap ~= nil then
    vim.api.nvim_win_set_option(win_id, 'wrap', options.wrap)
  end
  if options.cursorline ~= nil then
    vim.api.nvim_win_set_option(win_id, 'cursorline', options.cursorline)
  end

  return win_id
end

-- Display buffer in a floating window
-- Extracted from actions.lua display_diff_buffer_float
M.display_buffer_float = function(buf_id, config_key, options)
  options = options or {}
  local float_config = M.create_float_config(config_key, options)
  local win_id = vim.api.nvim_open_win(buf_id, true, float_config)

  -- Set window options for better appearance
  vim.api.nvim_win_set_option(win_id, 'wrap', options.wrap or false)
  vim.api.nvim_win_set_option(win_id, 'cursorline', options.cursorline or true)

  return win_id
end

-- Display buffer based on configuration (split or float)
-- Extracted and generalized from actions.lua display_diff_buffer
M.display_buffer = function(buf_id, display_mode, split_direction, config_key, options)
  options = options or {}
  local win_id

  if display_mode == 'float' then
    win_id = M.display_buffer_float(buf_id, config_key, options)
  else
    win_id = M.display_buffer_split(buf_id, split_direction, options)
  end

  return win_id
end

-- Setup close keymaps for buffer
-- Extracted from actions.lua keymap setup patterns
M.setup_close_keymaps = function(buf_id, win_id, config_key_prefix)
  config_key_prefix = config_key_prefix or 'keybinds.diff_window'
  
  local close_key = config.get_first_keybind(config_key_prefix .. '.close') or 'q'
  local close_alt_key = config.get_first_keybind(config_key_prefix .. '.close_alt') or '<Esc>'
  
  -- Set up close keymaps
  vim.keymap.set('n', close_key, function()
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, false)
    end
  end, { buffer = buf_id, noremap = true, silent = true })

  vim.keymap.set('n', close_alt_key, function()
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, false)
    end
  end, { buffer = buf_id, noremap = true, silent = true })
end

-- Complete buffer creation and display workflow
-- Combines all the above functions for common use cases
M.create_and_display_buffer = function(content, buffer_name, display_config)
  -- display_config should contain:
  -- - filetype: string
  -- - display_mode: 'split' or 'float'
  -- - split_direction: 'horizontal' or 'vertical'
  -- - config_key: string for float config
  -- - close_keymap_prefix: string for keymap config
  -- - options: table for additional options
  
  display_config = display_config or {}
  
  -- Create buffer with ANSI processing
  local buf_id = M.create_buffer_with_ansi(
    content, 
    buffer_name, 
    display_config.filetype,
    display_config.options
  )

  -- Display the buffer
  local win_id = M.display_buffer(
    buf_id,
    display_config.display_mode or 'split',
    display_config.split_direction or 'horizontal',
    display_config.config_key,
    display_config.options
  )

  -- Setup close keymaps
  if display_config.close_keymap_prefix then
    M.setup_close_keymaps(buf_id, win_id, display_config.close_keymap_prefix)
  end

  return buf_id, win_id
end

-- Helper function to create diff buffer (replaces actions.lua create_diff_buffer)
M.create_diff_buffer = function(content, commit_id, diff_type)
  local filetype = diff_type == 'stat' and 'diff' or 'git'
  return M.create_buffer_with_ansi(
    content, 
    string.format('jj-diff-%s', commit_id or 'unknown'), 
    filetype,
    { unique_name = true }
  )
end

-- Helper function to create status buffer (replaces actions.lua create_status_buffer)
M.create_status_buffer = function(content)
  return M.create_buffer_with_ansi(
    content, 
    'jj-status', 
    'text',
    { unique_name = true }
  )
end

-- Helper function to display diff buffer (replaces actions.lua display_diff_buffer)
M.display_diff_buffer = function(buf_id, display_mode, split_direction)
  local win_id = M.display_buffer(
    buf_id,
    display_mode or 'split',
    split_direction or 'horizontal',
    'diff.float'
  )
  
  M.setup_close_keymaps(buf_id, win_id, 'keybinds.diff_window')
  return win_id
end

-- Helper function to display status buffer (replaces actions.lua display_status_buffer)
M.display_status_buffer = function(buf_id, display_mode, split_direction)
  local win_id = M.display_buffer(
    buf_id,
    display_mode or 'split',
    split_direction or 'horizontal',
    'status.float'
  )
  
  M.setup_close_keymaps(buf_id, win_id, 'keybinds.status_window')
  return win_id
end

return M