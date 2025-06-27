local M = {}

local ansi = require('jj-nvim.utils.ansi')
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')

-- Constants
local BUFFER_CONFIG = {
  modifiable = false,
  readonly = true,
  buftype = 'nofile',
  bufhidden = 'wipe',
  swapfile = false,
  filetype = 'jj-log',
}

-- Helper function to configure buffer options
local function configure_buffer(buf_id)
  for option, value in pairs(BUFFER_CONFIG) do
    vim.api.nvim_buf_set_option(buf_id, option, value)
  end
end

-- Store commit data for the current buffer
local buffer_state = {
  commits = {},           -- Array of commit objects
  buf_id = nil,          -- Current buffer ID
  current_mode = nil,    -- Current rendering mode
}

-- Create buffer using commit-based rendering (new method)
M.create_from_commits = function(commits, mode)
  local buf_id = vim.api.nvim_create_buf(false, true)
  
  vim.api.nvim_buf_set_name(buf_id, 'JJ Log')
  
  ansi.setup_highlights()
  
  -- Store state
  buffer_state.commits = commits or {}
  buffer_state.buf_id = buf_id
  buffer_state.current_mode = mode or 'comfortable'
  
  -- Render commits and set buffer content
  M.update_from_commits(buf_id, commits, mode)
  
  configure_buffer(buf_id)
  
  return buf_id
end

-- Legacy create method for backward compatibility
M.create = function(content)
  -- If content is nil, parse commits and use new method
  if not content then
    local commits, err = parser.parse_all_commits_with_separate_graph()
    if err then
      vim.notify("Failed to parse commits: " .. err, vim.log.levels.ERROR)
      commits = {}
    end
    -- Ensure commits is not nil
    commits = commits or {}
    return M.create_from_commits(commits)
  end
  
  -- Legacy path: create buffer from raw content
  local buf_id = vim.api.nvim_create_buf(false, true)
  
  vim.api.nvim_buf_set_name(buf_id, 'JJ Log')
  
  ansi.setup_highlights()
  
  local lines = vim.split(content, '\n', { plain = true })
  M.set_lines_with_highlights(buf_id, lines)
  
  configure_buffer(buf_id)
  
  return buf_id
end

M.set_lines_with_highlights = function(buf_id, lines)
  local clean_lines = {}
  local highlights = {}
  
  -- Debug: Check if we have ANSI codes in the input
  local has_ansi = false
  local debug_line = ""
  for _, line in ipairs(lines) do
    if line:find('\27%[') then
      has_ansi = true
      debug_line = line
      break
    end
  end
  
  -- Debug: Log what we found (remove this after testing)
  -- vim.notify("ANSI found: " .. tostring(has_ansi), vim.log.levels.INFO)
  
  if not has_ansi then
    -- No ANSI codes found, just set lines normally
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    return
  end
  
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
  
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, clean_lines)
  
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf_id, -1, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end
end

M.update = function(buf_id, content)
  if not vim.api.nvim_buf_is_valid(buf_id) then
    return false
  end
  
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', false)
  
  vim.api.nvim_buf_clear_namespace(buf_id, -1, 0, -1)
  
  local lines = vim.split(content, '\n', { plain = true })
  M.set_lines_with_highlights(buf_id, lines)
  
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', true)
  
  return true
end

-- Update buffer content from commit objects
M.update_from_commits = function(buf_id, commits, mode)
  if not vim.api.nvim_buf_is_valid(buf_id) then
    return false
  end
  
  -- Update state
  buffer_state.commits = commits or {}
  buffer_state.buf_id = buf_id
  buffer_state.current_mode = mode or buffer_state.current_mode or 'comfortable'
  
  -- Render commits with highlights (window width will be retrieved from config)
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, buffer_state.current_mode)
  
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', false)
  
  -- Clear existing content and highlights
  vim.api.nvim_buf_clear_namespace(buf_id, -1, 0, -1)
  
  -- Extract clean lines and apply highlights
  local clean_lines = {}
  local highlights = {}
  
  for line_nr, line_data in ipairs(highlighted_lines) do
    table.insert(clean_lines, line_data.text)
    
    -- Apply highlight segments
    local col = 0
    for _, segment in ipairs(line_data.segments) do
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
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, clean_lines)
  
  -- Apply highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf_id, -1, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end
  
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', true)
  
  return true
end

-- Refresh buffer with latest commit data
M.refresh = function(buf_id)
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    return false
  end
  
  -- Parse latest commits using separate graph approach
  local commits, err = parser.parse_all_commits_with_separate_graph()
  if err then
    vim.notify("Failed to refresh commits: " .. err, vim.log.levels.ERROR)
    return false
  end
  
  -- Ensure commits is not nil
  commits = commits or {}
  
  return M.update_from_commits(buf_id, commits, buffer_state.current_mode)
end

-- Get commit at a specific line number
M.get_commit_at_line = function(line_number)
  return renderer.get_commit_at_line(buffer_state.commits, line_number)
end

-- Get the current commit (where cursor is positioned)
M.get_current_commit = function(buf_id)
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    return nil
  end
  
  -- Get cursor position (if this buffer is in a window)
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win_id) == buf_id then
      local cursor = vim.api.nvim_win_get_cursor(win_id)
      local line_number = cursor[1]
      return M.get_commit_at_line(line_number)
    end
  end
  
  return nil
end

-- Get all commits in the buffer
M.get_all_commits = function()
  return buffer_state.commits
end

-- Get commits (alias for compatibility with window multi-select functions)
M.get_commits = function(buf_id)
  return buffer_state.commits
end

-- Get all header line numbers for navigation
M.get_header_lines = function()
  return renderer.get_all_header_lines(buffer_state.commits)
end

-- Change rendering mode and update display
M.set_mode = function(buf_id, mode)
  if not vim.api.nvim_buf_is_valid(buf_id) then
    return false
  end
  
  buffer_state.current_mode = mode
  return M.update_from_commits(buf_id, buffer_state.commits, mode)
end

-- Get current rendering mode
M.get_mode = function()
  return buffer_state.current_mode
end

return M