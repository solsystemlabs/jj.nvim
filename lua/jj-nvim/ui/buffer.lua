local M = {}

local ansi = require('jj-nvim.utils.ansi')
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local status = require('jj-nvim.ui.status')
local config = require('jj-nvim.config')
local validation = require('jj-nvim.utils.validation')
local window_utils = require('jj-nvim.utils.window')

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
  commits = {},       -- Array of commit objects
  buf_id = nil,       -- Current buffer ID
  current_mode = nil, -- Current rendering mode
}

-- Create buffer using commit-based rendering (new method)
M.create_from_commits = function(commits, revset)
  local buf_id = vim.api.nvim_create_buf(false, true)

  -- Set buffer name with revset info if enabled
  local buffer_name = 'JJ Log'
  if config.get('log.show_revset_in_title') and revset and revset ~= 'all()' then
    buffer_name = buffer_name .. ' (' .. revset .. ')'
  end
  vim.api.nvim_buf_set_name(buf_id, buffer_name)

  ansi.setup_highlights()

  -- Store state
  buffer_state.commits = commits or {}
  buffer_state.buf_id = buf_id
  buffer_state.current_revset = revset

  -- Find current working copy commit and update status
  local current_working_copy_id = nil
  local current_working_copy_description = nil
  for _, commit in ipairs(commits) do
    if commit.current_working_copy then
      current_working_copy_id = commit.short_change_id or commit.change_id
      current_working_copy_description = commit.description
      break
    end
  end

  -- Update status with working copy information
  status.update_status({
    current_commit_id = current_working_copy_id,
    current_commit_description = current_working_copy_description,
    repository_info = ""
  })

  -- Render commits and set buffer content
  M.update_from_commits(buf_id, commits)

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

  -- Check if we have ANSI codes in the input
  local has_ansi = false
  for _, line in ipairs(lines) do
    if line:find('\27%[') then
      has_ansi = true
      break
    end
  end

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
M.update_from_commits = function(buf_id, commits, mode, window_width)
  if not validation.buffer(buf_id) then
    return false
  end

  -- Update state
  buffer_state.commits = commits or {}
  buffer_state.buf_id = buf_id
  buffer_state.current_mode = mode or buffer_state.current_mode or 'comfortable'

  -- Get window width (fallback to config if not provided)
  local raw_width = window_width or config.get('window.width') or 80

  -- Calculate effective width for content rendering (accounting for gutter columns)
  local effective_width = raw_width - 2 -- Account for left (1) + right (1) gutter columns

  -- Generate status lines using raw width for proper status box sizing
  local status_lines = status.build_status_content(raw_width)
  local status_height = #status_lines

  -- Render commits with highlights using effective width for proper text wrapping
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, buffer_state.current_mode)

  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', false)

  -- Clear existing content and highlights
  vim.api.nvim_buf_clear_namespace(buf_id, -1, 0, -1)

  -- Build final content: status lines + commit lines
  local clean_lines = {}
  local highlights = {}

  -- Add status lines
  for _, status_line in ipairs(status_lines) do
    table.insert(clean_lines, status_line)
  end

  -- Add commit content with adjusted line numbers for highlights
  for line_nr, line_data in ipairs(highlighted_lines) do
    table.insert(clean_lines, line_data.text)

    -- Apply highlight segments (adjust line numbers by status height)
    local adjusted_line_nr = line_nr + status_height - 1 -- -1 because line numbers are 0-based
    local col = 0
    for _, segment in ipairs(line_data.segments) do
      if segment.highlight and segment.text ~= '' then
        table.insert(highlights, {
          line = adjusted_line_nr,
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

  -- Apply status window highlighting (only to status area)
  status.apply_status_highlighting(buf_id, status_height)

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
      local display_line_number = cursor[1]

      -- Get window width for status height calculation
      local window_width = vim.api.nvim_win_get_width(win_id)

      -- Convert display line to log line (accounting for status lines)
      local log_line_number = M.get_log_line_number(display_line_number, window_width)

      -- If cursor is in status area, return nil
      if log_line_number <= 0 then
        return nil
      end

      return M.get_commit_at_line(log_line_number)
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

-- Get all header line numbers for navigation (adjusted for status display)
M.get_header_lines = function(window_width)
  local log_header_lines = renderer.get_all_header_lines(buffer_state.commits)

  -- Adjust all line numbers to account for status display
  local display_header_lines = {}
  for _, log_line in ipairs(log_header_lines) do
    local display_line = M.get_display_line_number(log_line, window_width)
    table.insert(display_header_lines, display_line)
  end

  return display_header_lines
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

-- Get the height of the status display
M.get_status_height = function(window_width)
  return status.calculate_status_height(window_width)
end

-- Update status information and refresh buffer
M.update_status = function(buf_id, status_updates, window_width)
  if not vim.api.nvim_buf_is_valid(buf_id) then
    return false
  end

  -- Update status state
  status.update_status(status_updates)

  -- Refresh buffer with current commits and updated status
  return M.update_from_commits(buf_id, buffer_state.commits, buffer_state.current_mode, window_width)
end

-- Get status-adjusted line number for navigation
M.get_log_line_number = function(display_line_number, window_width)
  local status_height = M.get_status_height(window_width)
  return display_line_number - status_height -- Convert to 1-based log line
end

-- Get display line number from log line number
M.get_display_line_number = function(log_line_number, window_width)
  local status_height = M.get_status_height(window_width)
  return log_line_number + status_height -- Convert to display line
end

-- Update buffer with fresh data and automatically refresh status information
-- This is the centralized function that should be called for all data refreshes
M.update_from_fresh_data = function(commits, revset)
  if not buffer_state.buf_id or not vim.api.nvim_buf_is_valid(buffer_state.buf_id) then
    return false
  end

  -- Update commit data and revset
  buffer_state.commits = commits or {}
  if revset then
    buffer_state.current_revset = revset

    -- Update buffer name if revset display is enabled
    local buffer_name = 'JJ Log'
    if config.get('log.show_revset_in_title') and revset and revset ~= 'all()' then
      buffer_name = buffer_name .. ' (' .. revset .. ')'
    end
    vim.api.nvim_buf_set_name(buffer_state.buf_id, buffer_name)
  end

  -- Find current working copy commit from fresh data
  local current_working_copy_id = nil
  local current_working_copy_description = nil
  for _, commit in ipairs(commits) do
    if commit.current_working_copy then
      current_working_copy_id = commit.short_change_id or commit.change_id
      current_working_copy_description = commit.description
      break
    end
  end

  -- Get window width for proper rendering
  local window_width = nil
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win_id) == buffer_state.buf_id then
      window_width = vim.api.nvim_win_get_width(win_id)
      break
    end
  end
  window_width = window_width or config.get('window.width') or 80

  -- Update status with fresh working copy information
  status.update_status({
    current_commit_id = current_working_copy_id,
    current_commit_description = current_working_copy_description,
    repository_info = ""
  })

  -- Update buffer content with fresh data and status
  return M.update_from_commits(buffer_state.buf_id, commits, buffer_state.current_mode, window_width)
end

return M

