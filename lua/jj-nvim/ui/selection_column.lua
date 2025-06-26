local M = {}

-- Selection column configuration
local SELECTION_CONFIG = {
  width = 2,                    -- Column width: "● " or "○ "
  unselected_char = '○',        -- Unselected indicator
  selected_char = '●',          -- Selected indicator
  background_hl = 'JJSelectionColumn',
  selected_hl = 'JJSelectedCommit',
  unselected_hl = 'JJUnselectedCommit',
}

-- Setup highlight groups for selection column
local function setup_selection_highlights()
  vim.api.nvim_set_hl(0, 'JJSelectionColumn', { bg = '#2c2c2c' })     -- Light gray background
  vim.api.nvim_set_hl(0, 'JJSelectedCommit', { fg = '#fb4934', bold = true })   -- Orange/red for selected
  vim.api.nvim_set_hl(0, 'JJUnselectedCommit', { fg = '#665c54' })    -- Dim gray for unselected
end

-- Get the width of the selection column
M.get_selection_column_width = function()
  return SELECTION_CONFIG.width
end

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
    vim.notify(string.format("Removed %s from selection", commit.short_change_id or commit_id:sub(1, 8)), vim.log.levels.INFO)
  else
    -- Add to selection
    table.insert(new_selected, commit_id)
    vim.notify(string.format("Added %s to selection", commit.short_change_id or commit_id:sub(1, 8)), vim.log.levels.INFO)
  end
  
  return new_selected
end

-- Render selection column for a commit line
M.render_selection_indicator = function(commit, selected_commits)
  if not commit then
    -- For non-commit lines (elided sections, connectors), return spaces
    return string.rep(' ', SELECTION_CONFIG.width)
  end
  
  local is_selected = is_commit_selected(commit, selected_commits)
  local char = is_selected and SELECTION_CONFIG.selected_char or SELECTION_CONFIG.unselected_char
  
  return char .. ' '  -- Character + space to fill width
end


-- Highlight selected commits in the buffer
M.highlight_selected_commits = function(buf_id, mixed_entries, selected_commits)
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    return
  end
  
  setup_selection_highlights()
  
  local ns_id = vim.api.nvim_create_namespace('jj_selection_column')
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)
  
  for _, entry in ipairs(mixed_entries) do
    if entry.type == "commit" then
      local commit = entry
      local is_selected = is_commit_selected(commit, selected_commits)
      
      if commit.line_start and commit.line_end then
        -- Highlight the selection column area for all commit lines
        for line_idx = commit.line_start, commit.line_end do
          -- Highlight the selection column background
          vim.api.nvim_buf_add_highlight(buf_id, ns_id, SELECTION_CONFIG.background_hl, line_idx - 1, 0, SELECTION_CONFIG.width)
          
          -- Highlight the selection indicator if this is the header line
          if line_idx == commit.line_start then
            local hl_group = is_selected and SELECTION_CONFIG.selected_hl or SELECTION_CONFIG.unselected_hl
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, hl_group, line_idx - 1, 0, 1)
          end
        end
        
        -- Add subtle background highlighting for selected commits
        if is_selected then
          for line_idx = commit.line_start, commit.line_end do
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJCommitSelected', line_idx - 1, SELECTION_CONFIG.width, -1)
          end
        end
      end
    end
  end
end


return M