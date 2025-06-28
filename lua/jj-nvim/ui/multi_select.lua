local M = {}

-- Check if a commit is selected
local function is_commit_selected(commit, selected_commits)
  if not commit then
    return false
  end
  
  -- Default to empty selection if not provided
  selected_commits = selected_commits or {}
  
  local commit_id = commit.change_id or commit.short_change_id
  if not commit_id then
    return false
  end
  
  for _, selected_id in ipairs(selected_commits) do
    if selected_id == commit_id then
      return true
    end
  end
  
  return false
end

-- Toggle commit selection
M.toggle_commit_selection = function(commit, selected_commits)
  if not commit then
    vim.notify("No commit to toggle", vim.log.levels.WARN)
    return selected_commits
  end
  
  local commit_id = commit.change_id or commit.short_change_id
  if not commit_id then
    vim.notify("Invalid commit: missing ID", vim.log.levels.WARN)
    return selected_commits
  end
  
  -- Create a copy of selected_commits to avoid modifying the original
  local new_selected = {}
  for _, id in ipairs(selected_commits) do
    table.insert(new_selected, id)
  end
  
  -- Check if commit is already selected
  local found_index = nil
  for i, selected_id in ipairs(new_selected) do
    if selected_id == commit_id then
      found_index = i
      break
    end
  end
  
  if found_index then
    -- Remove from selection
    table.remove(new_selected, found_index)
  else
    -- Add to selection
    table.insert(new_selected, commit_id)
  end
  
  return new_selected
end

-- Setup highlight groups for multi-select
local function setup_multi_select_highlights()
  -- Background highlight for selected commits - similar to navigation highlighting but distinct
  vim.api.nvim_set_hl(0, 'JJSelectedCommitBg', { bg = '#4a4a4a' })  -- Subtle gray background, preserve original text colors
end

-- Highlight selected commits with background color (full window width like navigation)
M.highlight_selected_commits = function(buf_id, mixed_entries, selected_commits, window_width)
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    return
  end
  
  setup_multi_select_highlights()
  
  local ns_id = vim.api.nvim_create_namespace('jj_multi_select')
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)
  
  -- Get window width if not provided
  if not window_width then
    -- Try to get from window state, fallback to reasonable default
    local win_id = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_is_valid(win_id) then
      window_width = vim.api.nvim_win_get_width(win_id)
    else
      window_width = 80
    end
  end
  
  -- Need buffer module for coordinate conversion
  local buffer = require('jj-nvim.ui.buffer')
  
  for _, entry in ipairs(mixed_entries) do
    -- Check if this is a commit object (most commits don't have .type field)
    local is_commit = (entry.change_id ~= nil or entry.short_change_id ~= nil) and entry.type ~= "elided"
    
    if is_commit then
      local commit = entry
      local is_selected = is_commit_selected(commit, selected_commits)
      
      if is_selected and commit.line_start and commit.line_end then
        -- Convert log line numbers to display line numbers for highlighting
        local display_start = buffer.get_display_line_number(commit.line_start, window_width)
        local display_end = buffer.get_display_line_number(commit.line_end, window_width)
        
        -- Add background highlighting for selected commits with full window width
        for line_idx = display_start, display_end do
          -- Get the actual line content to see its length
          local line_content = vim.api.nvim_buf_get_lines(buf_id, line_idx - 1, line_idx, false)[1] or ""
          local content_length = vim.fn.strdisplaywidth(line_content)
          
          -- Highlight the actual content
          vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJSelectedCommitBg', line_idx - 1, 0, -1)
          
          -- Extend highlighting to full window width if content is shorter
          if content_length < window_width then
            -- Add virtual text to fill the remaining space
            vim.api.nvim_buf_set_extmark(buf_id, ns_id, line_idx - 1, #line_content, {
              virt_text = { { string.rep(" ", window_width - content_length), 'JJSelectedCommitBg' } },
              virt_text_pos = 'inline'
            })
          end
        end
      end
    end
  end
end

-- Clear all selections
M.clear_all_selections = function()
  return {}
end

return M