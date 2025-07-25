local M = {}

local buffer = require('jj-nvim.ui.buffer')
local validation = require('jj-nvim.utils.validation')
local window_utils = require('jj-nvim.utils.window')

-- Helper function to get current view type
local function get_current_view()
  local window_module = require('jj-nvim.ui.window')
  return window_module.get_current_view()
end

-- Helper function to get navigable lines based on current view
local function get_navigable_lines(win_id, window_width)
  local current_view = get_current_view()
  
  if current_view == "bookmark" then
    -- In bookmark view, get bookmark lines from window state
    local window_module = require('jj-nvim.ui.window')
    local bookmark_data = window_module.get_bookmark_data()
    
    if not bookmark_data then
      return {}
    end
    
    local status_height = buffer.get_status_height(window_width)
    local bookmark_lines = {}
    
    -- Calculate line numbers for each bookmark (status_height + bookmark_index)
    -- The bookmark renderer starts directly with bookmarks (no header)
    local header_offset = 0  -- No header in new jj-style renderer
    
    for i, bookmark in ipairs(bookmark_data) do
      local line_num = status_height + header_offset + i
      table.insert(bookmark_lines, line_num)
    end
    
    return bookmark_lines
  else
    -- In log view, use commit header lines
    return buffer.get_header_lines(window_width)
  end
end

-- Helper function to ensure cursor stays in log area (not status area)
local function ensure_cursor_in_log_area(win_id)
  if not validation.window(win_id) then
    return
  end
  
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  local window_width = window_utils.get_width(win_id)
  local status_height = buffer.get_status_height(window_width)
  
  -- Get buffer info for validation
  local buf_id = vim.api.nvim_win_get_buf(win_id)
  local line_count = vim.api.nvim_buf_line_count(buf_id)
  
  -- If cursor is in status area, move to first navigable item
  if current_line <= status_height then
    local navigable_lines = get_navigable_lines(win_id, window_width)
    if navigable_lines and #navigable_lines > 0 then
      local target_line = navigable_lines[1]
      if target_line > 0 and target_line <= line_count then
        vim.api.nvim_win_set_cursor(win_id, {target_line, 0})
      end
    else
      local safe_line = math.min(status_height + 1, line_count)
      if safe_line > 0 then
        vim.api.nvim_win_set_cursor(win_id, {safe_line, 0})
      end
    end
  else
    -- Ensure current cursor position is still valid
    if current_line > line_count then
      local safe_line = math.max(status_height + 1, math.min(line_count, 1))
      vim.api.nvim_win_set_cursor(win_id, {safe_line, 0})
    end
  end
end

-- Add function to move cursor to first commit (public function)
M.goto_first_commit_after_status = function(win_id)
  ensure_cursor_in_log_area(win_id)
end

-- Helper function to collapse all expanded commits (only in log view)
local function collapse_expanded_commits(win_id)
  local current_view = get_current_view()
  
  -- Only collapse commits in log view
  if current_view ~= "log" then
    return
  end
  
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
        local window_utils = require('jj-nvim.utils.window')
        local window_width = window_utils.get_width(win_id)
        buffer.update_from_commits(buf_id, all_commits, buffer.get_mode(), window_width)
      end
    end
  end
end

-- Navigate to the next commit
M.next_commit = function(win_id)
  if not validation.window(win_id) then
    return false
  end
  
  -- Collapse any expanded commits before navigating
  collapse_expanded_commits(win_id)
  
  local buf_id = vim.api.nvim_win_get_buf(win_id)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  -- Get all navigable lines for current view
  local window_width = window_utils.get_width(win_id)
  local navigable_lines = get_navigable_lines(win_id, window_width)
  if not navigable_lines or #navigable_lines == 0 then
    return false
  end
  
  -- Find the next navigable line after current position
  local next_line = nil
  for _, line_num in ipairs(navigable_lines) do
    if line_num > current_line then
      next_line = line_num
      break
    end
  end
  
  -- If no next commit found, don't wrap (stay at current position)
  if not next_line then
    return false
  end
  
  -- Validate the line number before setting cursor
  if next_line then
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    local line_count = vim.api.nvim_buf_line_count(buf_id)
    if next_line > 0 and next_line <= line_count then
      vim.api.nvim_win_set_cursor(win_id, {next_line, 0})
      return true
    end
  end
  
  -- If we can't navigate, ensure cursor is in a valid position
  ensure_cursor_in_log_area(win_id)
  return false
end

-- Navigate to the previous commit
M.prev_commit = function(win_id)
  if not validation.window(win_id) then
    return false
  end
  
  -- Collapse any expanded commits before navigating
  collapse_expanded_commits(win_id)
  
  local buf_id = vim.api.nvim_win_get_buf(win_id)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local current_line = cursor[1]
  
  -- Get all navigable lines for current view
  local window_width = window_utils.get_width(win_id)
  local navigable_lines = get_navigable_lines(win_id, window_width)
  if not navigable_lines or #navigable_lines == 0 then
    return false
  end
  
  -- Find the previous navigable line before current position
  local prev_line = nil
  for i = #navigable_lines, 1, -1 do
    local line_num = navigable_lines[i]
    if line_num < current_line then
      prev_line = line_num
      break
    end
  end
  
  -- If no previous commit found, don't wrap (stay at current position)
  if not prev_line then
    return false
  end
  
  -- Validate the line number before setting cursor
  if prev_line then
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    local line_count = vim.api.nvim_buf_line_count(buf_id)
    if prev_line > 0 and prev_line <= line_count then
      vim.api.nvim_win_set_cursor(win_id, {prev_line, 0})
      return true
    end
  end
  
  -- If we can't navigate, ensure cursor is in a valid position
  ensure_cursor_in_log_area(win_id)
  return false
end

-- Navigate to a specific commit by index (0-based)
M.goto_commit = function(win_id, commit_index)
  if not validation.window(win_id) then
    return false
  end
  
  -- Collapse any expanded commits before navigating
  collapse_expanded_commits(win_id)
  
  local window_width = window_utils.get_width(win_id)
  local navigable_lines = get_navigable_lines(win_id, window_width)
  if not navigable_lines or commit_index < 0 or commit_index >= #navigable_lines then
    return false
  end
  
  local target_line = navigable_lines[commit_index + 1] -- Convert to 1-based
  
  -- Validate the line number before setting cursor
  if target_line then
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    local line_count = vim.api.nvim_buf_line_count(buf_id)
    if target_line > 0 and target_line <= line_count then
      vim.api.nvim_win_set_cursor(win_id, {target_line, 0})
      return true
    end
  end
  
  -- If we can't navigate, ensure cursor is in a valid position
  ensure_cursor_in_log_area(win_id)
  return false
end

-- Navigate to the first commit
M.goto_first_commit = function(win_id)
  return M.goto_commit(win_id, 0)
end

-- Navigate to the last commit
M.goto_last_commit = function(win_id)
  local window_width = window_utils.get_width(win_id)
  local navigable_lines = get_navigable_lines(win_id, window_width)
  if not navigable_lines or #navigable_lines == 0 then
    return false
  end
  return M.goto_commit(win_id, #navigable_lines - 1)
end

-- Navigate to the current working copy commit (if visible)
M.goto_current_commit = function(win_id)
  if not validation.window(win_id) then
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

-- Get the commit currently under the cursor (or bookmark in bookmark view)
M.get_current_commit = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return nil
  end
  
  local current_view = get_current_view()
  
  if current_view == "bookmark" then
    -- In bookmark view, return bookmark information
    local cursor = vim.api.nvim_win_get_cursor(win_id)
    local current_line = cursor[1]
    local window_width = window_utils.get_width(win_id)
    local status_height = buffer.get_status_height(window_width)
    
    local window_module = require('jj-nvim.ui.window')
    local bookmark_data = window_module.get_bookmark_data()
    
    if not bookmark_data then
      return nil
    end
    
    -- Calculate which bookmark line we're on
    local header_offset = 0  -- No header in new jj-style renderer
    local bookmark_line_offset = current_line - status_height - header_offset
    
    if bookmark_line_offset >= 1 and bookmark_line_offset <= #bookmark_data then
      return bookmark_data[bookmark_line_offset]
    end
    
    return nil
  else
    -- In log view, use normal commit logic
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    return buffer.get_current_commit(buf_id)
  end
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
  local navigable_lines = get_navigable_lines(win_id, window_width)
  if not navigable_lines then
    return false
  end
  
  for _, line_num in ipairs(navigable_lines) do
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
  local navigable_lines = get_navigable_lines(win_id, window_width)
  if not navigable_lines or #navigable_lines == 0 then
    return false
  end
  
  -- Find the nearest navigable line
  local nearest_line = navigable_lines[1]
  local min_distance = math.abs(current_line - nearest_line)
  
  for _, line_num in ipairs(navigable_lines) do
    local distance = math.abs(current_line - line_num)
    if distance < min_distance then
      min_distance = distance
      nearest_line = line_num
    end
  end
  
  -- Validate the line number before setting cursor
  if nearest_line then
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    local line_count = vim.api.nvim_buf_line_count(buf_id)
    if nearest_line > 0 and nearest_line <= line_count then
      vim.api.nvim_win_set_cursor(win_id, {nearest_line, 0})
      return true
    end
  end
  
  -- If we can't navigate, ensure cursor is in a valid position
  ensure_cursor_in_log_area(win_id)
  return false
end

-- Navigate to a commit by change_id or commit_id
M.goto_commit_by_id = function(win_id, target_id)
  if not validation.window(win_id) then
    return false
  end
  
  if not target_id then
    return false
  end
  
  local commits = buffer.get_all_commits()
  if not commits then
    return false
  end
  
  -- Find the commit with matching ID and get its line position directly
  for i, commit in ipairs(commits) do
    if commit.change_id == target_id or 
       commit.short_change_id == target_id or
       commit.id == target_id or
       commit.short_id == target_id then
      
      -- Get the commit's line position directly from the commit object
      local target_line = commit.line_start
      if target_line then
        -- Add status area height to get absolute buffer position
        local window_width = window_utils.get_width(win_id)
        local status_height = buffer.get_status_height(window_width)
        local absolute_line = target_line + status_height
        
        local buf_id = vim.api.nvim_win_get_buf(win_id)
        local line_count = vim.api.nvim_buf_line_count(buf_id)
        if absolute_line > 0 and absolute_line <= line_count then
          vim.api.nvim_win_set_cursor(win_id, {absolute_line, 0})
          return true
        end
      end
      
      -- Fallback to index-based navigation if line_start is not available
      return M.goto_commit(win_id, i - 1) -- Convert to 0-based index
    end
  end
  
  return false
end

return M