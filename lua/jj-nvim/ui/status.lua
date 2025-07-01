local M = {}

-- Status display configuration
local STATUS_CONFIG = {
  MIN_HEIGHT = 7,           -- Always reserve at least 7 lines (5 content + 2 borders)
  MIN_CONTENT_LINES = 5,    -- Minimum content lines (excluding borders)
  SEPARATOR_CHAR = "─",     -- Character for separator line
  MAX_LINE_LENGTH = 120,    -- Maximum line length before wrapping
}

-- Current status state
local status_state = {
  selected_count = 0,
  current_mode = "NORMAL",
  current_commit_id = nil,
  repository_info = "",
  last_window_width = 80,
  cached_height = STATUS_CONFIG.MIN_HEIGHT,
}

-- Calculate how many lines the status display needs based on window width
function M.calculate_status_height(window_width)
  window_width = window_width or 80
  
  -- Build status content to measure
  local content_lines = M.build_status_content(window_width)
  local needed_height = #content_lines
  
  -- Always use at least the minimum height
  local final_height = math.max(needed_height, STATUS_CONFIG.MIN_HEIGHT)
  
  -- Cache the result
  status_state.last_window_width = window_width
  status_state.cached_height = final_height
  
  return final_height
end

-- Build the actual status content lines
function M.build_status_content(window_width)
  window_width = window_width or status_state.last_window_width
  local lines = {}
  
  -- Calculate effective width for rendering (accounting for gutter columns)
  local window_utils = require('jj-nvim.utils.window')
  local effective_width = window_width - 2  -- Account for left + right gutter columns
  local content_width = effective_width - 4  -- Account for "│ " and " │"
  
  -- Top border (account for Unicode characters being 1 display width each)
  local border_length = effective_width - 2
  local top_border = "┌" .. string.rep("─", border_length) .. "┐"
  table.insert(lines, top_border)
  
  -- Content lines (ensure we have at least MIN_CONTENT_LINES)
  local content_lines = {}
  
  -- Line 1: Selection and mode information
  local selection_text = ""
  if status_state.selected_count > 0 then
    selection_text = string.format("Selected: %d commit%s", 
      status_state.selected_count, 
      status_state.selected_count > 1 and "s" or "")
  else
    selection_text = "No commits selected"
  end
  
  local mode_text = string.format("Mode: %s", status_state.current_mode)
  local line1_content = selection_text .. " │ " .. mode_text
  
  -- Handle wrapping
  if #line1_content > content_width then
    table.insert(content_lines, selection_text)
    table.insert(content_lines, mode_text)
  else
    table.insert(content_lines, line1_content)
  end
  
  -- Line 2: Repository and current working copy commit
  local repo_info = status_state.repository_info ~= "" and status_state.repository_info or "Repository: jj"
  local commit_info = ""
  if status_state.current_commit_id then
    commit_info = string.format("Working Copy: %s", status_state.current_commit_id)
  end
  
  local line2_content = commit_info ~= "" and (repo_info .. " │ " .. commit_info) or repo_info
  
  -- Handle wrapping
  if #line2_content > content_width then
    table.insert(content_lines, repo_info)
    if commit_info ~= "" then
      table.insert(content_lines, commit_info)
    end
  else
    table.insert(content_lines, line2_content)
  end
  
  -- Line 3: Help hints (log-window specific)
  local help_text = "Tab: expand │ Space: select │ rs: revsets │ rr: custom │ ?: help"
  if #help_text > content_width then
    -- Split into multiple lines if too long
    table.insert(content_lines, "Tab: expand │ Space: select │ rs: revsets")
    table.insert(content_lines, "rr: custom │ ?: help")
  else
    table.insert(content_lines, help_text)
  end
  
  -- Pad to minimum content lines
  while #content_lines < STATUS_CONFIG.MIN_CONTENT_LINES do
    table.insert(content_lines, "")
  end
  
  -- Add content lines with proper borders
  for _, content in ipairs(content_lines) do
    -- Calculate actual display width of content to pad correctly
    local content_display_width = vim.fn.strdisplaywidth(content)
    local padding_needed = content_width - content_display_width
    local content_padded = content .. string.rep(" ", math.max(0, padding_needed))
    local bordered_line = "│ " .. content_padded .. " │"
    table.insert(lines, bordered_line)
  end
  
  -- Bottom border
  local bottom_border = "└" .. string.rep("─", border_length) .. "┘"
  table.insert(lines, bottom_border)
  
  return lines
end

-- Update the status state
function M.update_status(updates)
  if updates.selected_count ~= nil then
    status_state.selected_count = updates.selected_count
  end
  if updates.current_mode then
    status_state.current_mode = updates.current_mode
  end
  if updates.current_commit_id then
    status_state.current_commit_id = updates.current_commit_id
  end
  if updates.repository_info then
    status_state.repository_info = updates.repository_info
  end
end

-- Get current status state
function M.get_status_state()
  return vim.deepcopy(status_state)
end

-- Get cached status height (avoids recalculation)
function M.get_cached_height()
  return status_state.cached_height
end

-- Reset status to defaults
function M.reset_status()
  status_state.selected_count = 0
  status_state.current_mode = "NORMAL"
  status_state.current_commit_id = nil
  status_state.repository_info = ""
end

return M