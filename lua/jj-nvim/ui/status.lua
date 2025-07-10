local M = {}

-- Status display configuration
local STATUS_CONFIG = {
  MIN_HEIGHT = 7,           -- Always reserve at least 7 lines (5 content + 2 borders)
  MIN_CONTENT_LINES = 5,    -- Minimum content lines (excluding borders)
  SEPARATOR_CHAR = "─",     -- Character for separator line
  MAX_LINE_LENGTH = 120,    -- Maximum line length before wrapping
}

-- Color highlight groups for status window
local STATUS_HIGHLIGHTS = {
  border = 'JJStatusBorder',
  selection_count = 'JJStatusSelection',
  mode = 'JJStatusMode',
  working_copy_label = 'JJStatusWorkingCopyLabel',
  commit_id = 'JJStatusCommitId',
  commit_description = 'JJStatusCommitDescription',
  help_key = 'JJStatusHelpKey',
  help_desc = 'JJStatusHelpDesc',
  separator = 'JJStatusSeparator',
}

-- Current status state
local status_state = {
  selected_count = 0,
  current_mode = "NORMAL",
  current_commit_id = nil,
  current_commit_description = nil,
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

-- Helper function to truncate text with ellipsis
local function truncate_with_ellipsis(text, max_length)
  if #text <= max_length then
    return text
  end
  return text:sub(1, max_length - 3) .. "..."
end

-- Helper function to wrap text intelligently
local function wrap_text_intelligently(text_segments, content_width)
  local wrapped_lines = {}
  local current_line = ""
  
  for i, segment in ipairs(text_segments) do
    local separator = (current_line ~= "") and " │ " or ""
    local test_line = current_line .. separator .. segment
    
    if #test_line <= content_width then
      -- Fits on current line
      current_line = test_line
    else
      -- Doesn't fit on current line
      if current_line ~= "" then
        -- Save current line and try to fit the segment on a new line
        table.insert(wrapped_lines, current_line)
        current_line = ""
      end
      
      -- Try to fit the segment on the new line
      if #segment <= content_width then
        current_line = segment
      else
        -- Segment is too long even for its own line, truncate it
        current_line = truncate_with_ellipsis(segment, content_width)
      end
    end
  end
  
  -- Add the final line if not empty
  if current_line ~= "" then
    table.insert(wrapped_lines, current_line)
  end
  
  return wrapped_lines
end

-- Setup color highlights for status window
function M.setup_highlights()
  local themes = require('jj-nvim.ui.themes')
  local theme = themes.get_theme('auto') -- Auto-detect theme
  
  -- Define highlight groups with theme colors
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.border, { fg = theme.colors.bright_black })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.selection_count, { fg = theme.colors.cyan })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.mode, { fg = theme.colors.yellow })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.working_copy_label, { fg = theme.colors.green })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.commit_id, { fg = theme.colors.bright_blue })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.commit_description, { fg = theme.colors.white })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.help_key, { fg = theme.colors.magenta })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.help_desc, { fg = theme.colors.bright_black })
  vim.api.nvim_set_hl(0, STATUS_HIGHLIGHTS.separator, { fg = theme.colors.bright_black })
end

-- Apply highlighting to status area using buffer highlights (not syntax)
function M.apply_status_highlighting(bufnr, status_height)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  
  M.setup_highlights()
  
  -- Get buffer content for the status area only
  local status_lines = vim.api.nvim_buf_get_lines(bufnr, 0, status_height, false)
  
  -- Apply highlights line by line for just the status area
  for line_nr = 0, status_height - 1 do
    if line_nr < #status_lines then
      local line = status_lines[line_nr + 1]
      M.apply_line_highlights(bufnr, line_nr, line)
    end
  end
end

-- Apply highlights to a specific line
function M.apply_line_highlights(bufnr, line_nr, line_content)
  -- Border characters
  local start_col = 1
  while start_col <= #line_content do
    local border_start, border_end = line_content:find('[┌┐└┘│─]', start_col)
    if border_start then
      vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.border, line_nr, border_start - 1, border_end)
      start_col = border_end + 1
    else
      break
    end
  end
  
  -- Selection count
  local sel_start, sel_end = line_content:find('Selected: %d+ commits?')
  if sel_start then
    vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.selection_count, line_nr, sel_start - 1, sel_end)
  end
  
  local no_sel_start, no_sel_end = line_content:find('No commits selected')
  if no_sel_start then
    vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.selection_count, line_nr, no_sel_start - 1, no_sel_end)
  end
  
  -- Mode
  local mode_start, mode_end = line_content:find('Mode: %w+')
  if mode_start then
    vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.mode, line_nr, mode_start - 1, mode_end)
  end
  
  -- Working copy label and commit ID
  local wc_start, wc_end = line_content:find('Working Copy:')
  if wc_start then
    vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.working_copy_label, line_nr, wc_start - 1, wc_end)
    
    -- Commit ID after "Working Copy: "
    local commit_start, commit_end = line_content:find('[a-f0-9]+', wc_end + 1)
    if commit_start then
      vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.commit_id, line_nr, commit_start - 1, commit_end)
    end
  end
  
  -- Help key bindings
  local help_patterns = {'Tab:', 'Space:', 'rs:', 'rr:', '%?:'}
  for _, pattern in ipairs(help_patterns) do
    local help_start, help_end = line_content:find(pattern)
    if help_start then
      vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.help_key, line_nr, help_start - 1, help_end)
    end
  end
  
  -- Help descriptions
  local desc_patterns = {'expand', 'select', 'revsets', 'custom', 'help'}
  for _, pattern in ipairs(desc_patterns) do
    local desc_start, desc_end = line_content:find('%f[%w]' .. pattern .. '%f[%W]')
    if desc_start then
      vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.help_desc, line_nr, desc_start - 1, desc_end)
    end
  end
  
  -- Separators
  start_col = 1
  while start_col <= #line_content do
    local sep_start, sep_end = line_content:find(' │ ', start_col)
    if sep_start then
      vim.api.nvim_buf_add_highlight(bufnr, -1, STATUS_HIGHLIGHTS.separator, line_nr, sep_start - 1, sep_end)
      start_col = sep_end + 1
    else
      break
    end
  end
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
  
  -- Use intelligent wrapping for line 1
  local line1_segments = {selection_text, mode_text}
  local line1_wrapped = wrap_text_intelligently(line1_segments, content_width)
  for _, line in ipairs(line1_wrapped) do
    table.insert(content_lines, line)
  end
  
  -- Line 2: Working copy information (with description)
  local line2_segments = {}
  
  if status_state.current_commit_id then
    local working_copy_text = string.format("Working Copy: %s", status_state.current_commit_id)
    table.insert(line2_segments, working_copy_text)
    
    -- Add description if available - let the wrapping function handle whether it fits
    if status_state.current_commit_description and status_state.current_commit_description ~= "" then
      table.insert(line2_segments, status_state.current_commit_description)
    end
  end
  
  -- Use intelligent wrapping for line 2
  if #line2_segments > 0 then
    local line2_wrapped = wrap_text_intelligently(line2_segments, content_width)
    for _, line in ipairs(line2_wrapped) do
      table.insert(content_lines, line)
    end
  end
  
  -- Line 3: Help hints (log-window specific) with intelligent wrapping
  local help_segments = {"Tab: expand", "rs: revsets", "rr: custom", "?: help"}
  local help_wrapped = wrap_text_intelligently(help_segments, content_width)
  for _, line in ipairs(help_wrapped) do
    table.insert(content_lines, line)
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
  if updates.current_commit_description then
    status_state.current_commit_description = updates.current_commit_description
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
  status_state.current_commit_description = nil
  status_state.repository_info = ""
end

-- Get available status highlight groups (for debugging/testing)
function M.get_highlight_groups()
  return STATUS_HIGHLIGHTS
end

return M