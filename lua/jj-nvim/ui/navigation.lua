local M = {}

local buffer = require('jj-nvim.ui.buffer')

-- Helper function to ensure cursor stays in log area (not status area)
local function ensure_cursor_in_log_area(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return
  end
  
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  local window_width = vim.api.nvim_win_get_width(win_id)
  local status_height = buffer.get_status_height(window_width)
  
  -- If cursor is in status area, move to first commit
  if current_line <= status_height then
    local header_lines = buffer.get_header_lines(window_width)
    if header_lines and #header_lines > 0 then
      vim.api.nvim_win_set_cursor(win_id, {header_lines[1], 0})
    else
      vim.api.nvim_win_set_cursor(win_id, {status_height + 1, 0})
    end
  end
end

-- Add function to move cursor to first commit (public function)
M.goto_first_commit_after_status = function(win_id)
  ensure_cursor_in_log_area(win_id)
end

-- Helper function to collapse all expanded commits
local function collapse_expanded_commits(win_id)
  local all_commits = buffer.get_commits()
  if all_commits then
    local has_changes = false
    for _, commit in ipairs(all_commits) do
      if commit.expanded then
        commit.expanded = false
        has_changes = true
      end
    end
    
    -- Re-render if there were changes
    if has_changes then
      local buf_id = vim.api.nvim_win_get_buf(win_id)
      if buf_id then
        buffer.update_from_commits(buf_id, all_commits, buffer.get_mode())
      end
    end
  end
end

-- Navigate to the next commit
M.next_commit = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  -- Collapse any expanded commits before navigating
  collapse_expanded_commits(win_id)
  
  local buf_id = vim.api.nvim_win_get_buf(win_id)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  -- Get all header lines for navigation
  local window_width = vim.api.nvim_win_get_width(win_id)
  local header_lines = buffer.get_header_lines(window_width)
  if not header_lines or #header_lines == 0 then
    return false
  end
  
  -- Find the next header line after current position
  local next_line = nil
  for _, line_num in ipairs(header_lines) do
    if line_num > current_line then
      next_line = line_num
      break
    end
  end
  
  -- If no next commit found, wrap to first commit
  if not next_line then
    next_line = header_lines[1]
  end
  
  -- Move cursor to the next commit header
  vim.api.nvim_win_set_cursor(win_id, {next_line, 0})
  return true
end

-- Navigate to the previous commit
M.prev_commit = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  -- Collapse any expanded commits before navigating
  collapse_expanded_commits(win_id)
  
  local buf_id = vim.api.nvim_win_get_buf(win_id)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  -- Get all header lines for navigation
  local window_width = vim.api.nvim_win_get_width(win_id)
  local header_lines = buffer.get_header_lines(window_width)
  if not header_lines or #header_lines == 0 then
    return false
  end
  
  -- Find the previous header line before current position
  local prev_line = nil
  for i = #header_lines, 1, -1 do
    local line_num = header_lines[i]
    if line_num < current_line then
      prev_line = line_num
      break
    end
  end
  
  -- If no previous commit found, wrap to last commit
  if not prev_line then
    prev_line = header_lines[#header_lines]
  end
  
  -- Move cursor to the previous commit header
  vim.api.nvim_win_set_cursor(win_id, {prev_line, 0})
  return true
end

-- Navigate to a specific commit by index (0-based)
M.goto_commit = function(win_id, commit_index)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  -- Collapse any expanded commits before navigating
  collapse_expanded_commits(win_id)
  
  local window_width = vim.api.nvim_win_get_width(win_id)
  local header_lines = buffer.get_header_lines(window_width)
  if not header_lines or commit_index < 0 or commit_index >= #header_lines then
    return false
  end
  
  local target_line = header_lines[commit_index + 1] -- Convert to 1-based
  vim.api.nvim_win_set_cursor(win_id, {target_line, 0})
  return true
end

-- Navigate to the first commit
M.goto_first_commit = function(win_id)
  return M.goto_commit(win_id, 0)
end

-- Navigate to the last commit
M.goto_last_commit = function(win_id)
  local window_width = vim.api.nvim_win_get_width(win_id)
  local header_lines = buffer.get_header_lines(window_width)
  if not header_lines or #header_lines == 0 then
    return false
  end
  return M.goto_commit(win_id, #header_lines - 1)
end

-- Navigate to the current working copy commit (if visible)
M.goto_current_commit = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  local commits = buffer.get_all_commits()
  if not commits then
    return false
  end
  
  -- Find the current working copy commit
  for i, commit in ipairs(commits) do
    if commit:is_current() then
      return M.goto_commit(win_id, i - 1) -- Convert to 0-based index
    end
  end
  
  return false
end

-- Get the commit currently under the cursor
M.get_current_commit = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return nil
  end
  
  local buf_id = vim.api.nvim_win_get_buf(win_id)
  return buffer.get_current_commit(buf_id)
end

-- Get the index of the commit currently under the cursor
M.get_current_commit_index = function(win_id)
  local current_commit = M.get_current_commit(win_id)
  if not current_commit then
    return nil
  end
  
  local commits = buffer.get_all_commits()
  if not commits then
    return nil
  end
  
  for i, commit in ipairs(commits) do
    if commit == current_commit then
      return i - 1 -- Return 0-based index
    end
  end
  
  return nil
end

-- Scroll to keep the current commit header in view
M.center_on_commit = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  -- Center the window on the current line
  vim.cmd('normal! zz')
  return true
end

-- Navigate and center on commit
M.next_commit_centered = function(win_id)
  if M.next_commit(win_id) then
    M.center_on_commit(win_id)
    return true
  end
  return false
end

M.prev_commit_centered = function(win_id)
  if M.prev_commit(win_id) then
    M.center_on_commit(win_id)
    return true
  end
  return false
end

-- Check if cursor is currently on a commit header line
M.is_on_commit_header = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  local window_width = vim.api.nvim_win_get_width(win_id)
  local header_lines = buffer.get_header_lines(window_width)
  if not header_lines then
    return false
  end
  
  for _, line_num in ipairs(header_lines) do
    if line_num == current_line then
      return true
    end
  end
  
  return false
end

-- Snap to the nearest commit header if not already on one
M.snap_to_commit_header = function(win_id)
  if M.is_on_commit_header(win_id) then
    return true -- Already on a header
  end
  
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  local window_width = vim.api.nvim_win_get_width(win_id)
  local header_lines = buffer.get_header_lines(window_width)
  if not header_lines or #header_lines == 0 then
    return false
  end
  
  -- Find the nearest header line
  local nearest_line = header_lines[1]
  local min_distance = math.abs(current_line - nearest_line)
  
  for _, line_num in ipairs(header_lines) do
    local distance = math.abs(current_line - line_num)
    if distance < min_distance then
      min_distance = distance
      nearest_line = line_num
    end
  end
  
  -- Move to the nearest header
  vim.api.nvim_win_set_cursor(win_id, {nearest_line, 0})
  return true
end

return M