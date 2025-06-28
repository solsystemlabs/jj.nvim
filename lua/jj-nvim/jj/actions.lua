local M = {}

local commands = require('jj-nvim.jj.commands')
local buffer = require('jj-nvim.ui.buffer')
local config = require('jj-nvim.config')
local commit_utils = require('jj-nvim.core.commit')
local ansi = require('jj-nvim.utils.ansi')

-- Helper function to get change ID from commit
local function get_change_id(commit)
  if not commit then
    return nil, "No commit provided"
  end
  
  local change_id = commit_utils.get_id(commit)
  if not change_id or change_id == "" then
    return nil, "Invalid commit: missing change ID"
  end
  
  return change_id, nil
end

-- Helper function to get short display ID from commit
local function get_short_display_id(commit, change_id)
  return commit_utils.get_display_id(commit)
end

-- Helper function to handle command execution with common error patterns
local function execute_with_error_handling(cmd_args, error_context)
  local result, err = commands.execute(cmd_args)
  
  if not result then
    local error_msg = err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot create change - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("duplicate") then
      error_msg = "Duplicate change IDs specified"
    end
    
    vim.notify(string.format("Failed to %s: %s", error_context, error_msg), vim.log.levels.ERROR)
    return false, error_msg
  end
  
  return result, nil
end

-- Edit the specified commit
M.edit_commit = function(commit)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end

  -- Don't allow editing the root commit
  if commit.root then
    vim.notify("Cannot edit the root commit", vim.log.levels.WARN)
    return false
  end

  local change_id, err = get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local display_id = get_short_display_id(commit, change_id)
  vim.notify(string.format("Editing commit %s...", display_id), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling({'edit', change_id}, "edit commit")
  if not result then
    return false
  end

  vim.notify(string.format("Now editing commit %s", display_id), vim.log.levels.INFO)
  return true
end

-- Get a user-friendly description of what the edit command will do
M.get_edit_description = function(commit)
  if not commit then
    return "No commit selected"
  end
  
  if commit.root then
    return "Cannot edit root commit"
  end
  
  local change_id = commit.short_change_id or commit.change_id:sub(1, 8)
  local description = commit:get_short_description()
  
  return string.format("Edit commit %s: %s", change_id, description)
end

-- Abandon the specified commit
M.abandon_commit = function(commit, on_success)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end

  -- Don't allow abandoning the root commit
  if commit.root then
    vim.notify("Cannot abandon the root commit", vim.log.levels.WARN)
    return false
  end

  -- Don't allow abandoning the current commit
  if commit:is_current() then
    vim.notify("Cannot abandon the current working copy commit", vim.log.levels.WARN)
    return false
  end

  local change_id, err = get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Confirm before abandoning
  local description = commit:get_short_description()
  local display_id = get_short_display_id(commit, change_id)
  local confirm_msg = string.format("Abandon commit %s: %s?", display_id, description)
  
  vim.ui.select({'Yes', 'No'}, {
    prompt = confirm_msg,
  }, function(choice)
    if choice == 'Yes' then
      vim.notify(string.format("Abandoning commit %s...", display_id), vim.log.levels.INFO)

      local result, exec_err = execute_with_error_handling({'abandon', change_id}, "abandon commit")
      if not result then
        return false
      end

      vim.notify(string.format("Abandoned commit %s", display_id), vim.log.levels.INFO)
      if on_success then on_success() end
      return true
    else
      vim.notify("Abandon cancelled", vim.log.levels.INFO)
      return false
    end
  end)
end

-- Helper function to extract new change ID from jj command output
local function extract_new_change_id(result)
  if not result then return nil end
  return result:match("Working copy now at: (%w+)")
end

-- Create a new child change from the specified parent commit
M.new_child = function(parent_commit, options)
  if not parent_commit then
    vim.notify("No parent commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}
  
  local change_id, err = get_change_id(parent_commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Special handling for root commit - jj actually allows this but warn user
  if parent_commit.root then
    local confirm_msg = "Create child of root commit? This will create a new branch. (y/N)"
    local choice = vim.fn.input(confirm_msg)
    if choice:lower() ~= 'y' and choice:lower() ~= 'yes' then
      vim.notify("New change cancelled", vim.log.levels.INFO)
      return false
    end
  end

  -- Build command arguments
  local cmd_args = {'new', change_id}
  
  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local display_id = get_short_display_id(parent_commit, change_id)
  vim.notify(string.format("Creating new child of commit %s...", display_id), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  -- Parse output for additional information
  local new_change_id = extract_new_change_id(result)
  if new_change_id then
    vim.notify(string.format("Created new change %s as child of %s", 
      new_change_id:sub(1, 8), display_id), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new child change of %s", display_id), vim.log.levels.INFO)
  end
  
  return true
end

-- Get a user-friendly description of what the new child command will do
M.get_new_child_description = function(parent_commit)
  if not parent_commit then
    return "No parent commit selected"
  end
  
  local change_id = parent_commit.short_change_id or parent_commit.change_id:sub(1, 8)
  local description = parent_commit:get_short_description()
  
  if parent_commit.root then
    return string.format("Create new branch from root %s: %s", change_id, description)
  end
  
  return string.format("Create new child of %s: %s", change_id, description)
end

-- Create a new child change with a custom message
M.new_child_with_message = function(parent_commit, message)
  return M.new_child(parent_commit, { message = message })
end

-- Create a new change after the specified commit (sibling)
M.new_after = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}
  
  local change_id, err = get_change_id(target_commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Build command arguments for jj new --after
  local cmd_args = {'new', '--after', change_id}
  
  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local display_id = get_short_display_id(target_commit, change_id)
  vim.notify(string.format("Creating new change after commit %s...", display_id), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  -- Parse output for additional information
  local new_change_id = extract_new_change_id(result)
  if new_change_id then
    vim.notify(string.format("Created new change %s after %s", 
      new_change_id:sub(1, 8), display_id), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new change after %s", display_id), vim.log.levels.INFO)
  end
  
  return true
end

-- Create a new change before the specified commit (insert)
M.new_before = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}
  
  local change_id, err = get_change_id(target_commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Don't allow inserting before root commit
  if target_commit.root then
    vim.notify("Cannot insert before the root commit", vim.log.levels.WARN)
    return false
  end

  -- Build command arguments for jj new --before
  local cmd_args = {'new', '--before', change_id}
  
  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local display_id = get_short_display_id(target_commit, change_id)
  vim.notify(string.format("Creating new change before commit %s...", display_id), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  -- Parse output for additional information
  local new_change_id = extract_new_change_id(result)
  if new_change_id then
    vim.notify(string.format("Created new change %s before %s", 
      new_change_id:sub(1, 8), display_id), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new change before %s", display_id), vim.log.levels.INFO)
  end
  
  return true
end


-- Create a new change with multiple parents using change IDs directly
M.new_with_change_ids = function(change_ids, options)
  if not change_ids or type(change_ids) ~= 'table' or #change_ids == 0 then
    vim.notify("No change IDs specified", vim.log.levels.WARN)
    return false
  end

  if #change_ids < 2 then
    vim.notify("At least 2 change IDs required for multi-parent change", vim.log.levels.WARN)
    return false
  end

  options = options or {}
  
  -- Build command arguments for jj new with multiple change IDs
  local cmd_args = {'new'}
  
  -- Add all change IDs directly
  for _, change_id in ipairs(change_ids) do
    table.insert(cmd_args, change_id)
  end
  
  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local changes_str = table.concat(change_ids, ", ")
  vim.notify(string.format("Creating merge commit with parents: %s...", changes_str), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create merge commit")
  if not result then
    return false
  end

  -- Parse output for additional information
  local new_change_id = extract_new_change_id(result)
  if new_change_id then
    vim.notify(string.format("Created merge commit %s with parents: %s", 
      new_change_id:sub(1, 8), changes_str), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created merge commit with parents: %s", changes_str), vim.log.levels.INFO)
  end
  
  return true
end

-- Abandon multiple commits
M.abandon_multiple_commits = function(selected_commit_ids, on_success)
  if not selected_commit_ids or #selected_commit_ids == 0 then
    vim.notify("No commits selected for abandoning", vim.log.levels.WARN)
    return false
  end

  -- Get all commits to validate the selected ones
  local all_commits = buffer.get_commits()
  if not all_commits then
    vim.notify("Failed to get commits from buffer", vim.log.levels.ERROR)
    return false
  end

  -- Find and validate selected commits
  local commits_to_abandon = {}
  local invalid_commits = {}
  
  for _, commit_id in ipairs(selected_commit_ids) do
    local commit = nil
    for _, c in ipairs(all_commits) do
      local c_id = c.change_id or c.short_change_id
      if c_id == commit_id then
        commit = c
        break
      end
    end
    
    if commit then
      -- Validate each commit
      if commit.root then
        table.insert(invalid_commits, string.format("%s (root commit)", commit.short_change_id or commit_id:sub(1, 8)))
      elseif commit:is_current() then
        table.insert(invalid_commits, string.format("%s (current commit)", commit.short_change_id or commit_id:sub(1, 8)))
      else
        table.insert(commits_to_abandon, commit)
      end
    else
      table.insert(invalid_commits, string.format("%s (not found)", commit_id:sub(1, 8)))
    end
  end

  -- Report invalid commits
  if #invalid_commits > 0 then
    vim.notify(string.format("Cannot abandon: %s", table.concat(invalid_commits, ", ")), vim.log.levels.WARN)
    if #commits_to_abandon == 0 then
      return false
    end
  end

  -- Confirm before abandoning
  local commit_count = #commits_to_abandon
  local commit_summaries = {}
  for _, commit in ipairs(commits_to_abandon) do
    local display_id = get_short_display_id(commit, commit.change_id or commit.short_change_id)
    local desc = commit:get_short_description()
    table.insert(commit_summaries, string.format("  %s: %s", display_id, desc))
  end
  
  local confirm_msg = string.format("Abandon %d commit%s?", commit_count, commit_count > 1 and "s" or "")
  if #commit_summaries <= 5 then
    confirm_msg = confirm_msg .. "\n" .. table.concat(commit_summaries, "\n")
  else
    confirm_msg = confirm_msg .. "\n" .. table.concat(commit_summaries, "\n", 1, 3) .. "\n  ... and " .. (#commit_summaries - 3) .. " more"
  end

  vim.ui.select({'Yes', 'No'}, {
    prompt = confirm_msg,
  }, function(choice)
    if choice == 'Yes' then
      -- Abandon all selected commits
      local change_ids = {}
      for _, commit in ipairs(commits_to_abandon) do
        local change_id, err = get_change_id(commit)
        if change_id then
          table.insert(change_ids, change_id)
        else
          vim.notify(string.format("Failed to get change ID for commit: %s", err), vim.log.levels.ERROR)
          return false
        end
      end

      vim.notify(string.format("Abandoning %d commit%s...", #change_ids, #change_ids > 1 and "s" or ""), vim.log.levels.INFO)

      -- Execute abandon command with all change IDs
      local cmd_args = {'abandon'}
      for _, change_id in ipairs(change_ids) do
        table.insert(cmd_args, change_id)
      end

      local result, exec_err = execute_with_error_handling(cmd_args, "abandon commits")
      if not result then
        return false
      end

      vim.notify(string.format("Abandoned %d commit%s", #change_ids, #change_ids > 1 and "s" or ""), vim.log.levels.INFO)
      if on_success then on_success() end
      return true
    else
      vim.notify("Abandon cancelled", vim.log.levels.INFO)
      return false
    end
  end)
end

-- Create a diff buffer and display diff content
local function create_diff_buffer(content, commit_id, diff_type)
  -- Create a new buffer for the diff
  local buf_id = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer name and type
  local buf_name = string.format('jj-diff-%s', commit_id or 'unknown')
  vim.api.nvim_buf_set_name(buf_id, buf_name)
  
  -- Configure buffer options
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', false)
  vim.api.nvim_buf_set_option(buf_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'swapfile', false)
  
  -- Set appropriate filetype for syntax highlighting
  if diff_type == 'stat' then
    vim.api.nvim_buf_set_option(buf_id, 'filetype', 'diff')
  else
    vim.api.nvim_buf_set_option(buf_id, 'filetype', 'git')
  end
  
  -- Setup ANSI highlights for colored diff output
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

-- Display diff buffer in a split window
local function display_diff_buffer(buf_id, split_direction)
  split_direction = split_direction or 'horizontal'
  
  -- Get current window to return focus later
  local current_win = vim.api.nvim_get_current_win()
  
  -- Create split window
  if split_direction == 'vertical' then
    vim.cmd('vsplit')
  else
    vim.cmd('split')
  end
  
  -- Switch to the new buffer
  vim.api.nvim_win_set_buf(0, buf_id)
  
  -- Set up keymap to close diff window
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(0, false)
  end, { buffer = buf_id, noremap = true, silent = true })
  
  -- Set up keymap to return to log window
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(0, false)
  end, { buffer = buf_id, noremap = true, silent = true })
  
  return vim.api.nvim_get_current_win()
end

-- Show diff for the specified commit
M.show_diff = function(commit, format, options)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end
  
  -- Don't allow diff for root commit (usually has no changes)
  if commit.root then
    vim.notify("Cannot show diff for root commit", vim.log.levels.WARN)
    return false
  end
  
  local change_id, err = get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end
  
  local display_id = get_short_display_id(commit)
  
  -- Get diff format from config if not specified
  format = format or config.get('diff.format') or 'git'
  options = options or {}
  
  -- Set diff options based on format
  local diff_options = { silent = true }
  if format == 'git' then
    diff_options.git = true
  elseif format == 'stat' then
    diff_options.stat = true
  elseif format == 'color-words' then
    diff_options.color_words = true
  elseif format == 'name-only' then
    diff_options.name_only = true
  end
  
  vim.notify(string.format("Getting diff for commit %s...", display_id), vim.log.levels.INFO)
  
  -- Get the diff content
  local diff_content, diff_err = commands.get_diff(change_id, diff_options)
  if not diff_content then
    local error_msg = diff_err or "Unknown error"
    
    -- Handle common error cases
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("ambiguous") then
      error_msg = "Ambiguous commit ID - please specify more characters"
    end
    
    vim.notify(string.format("Failed to get diff: %s", error_msg), vim.log.levels.ERROR)
    return false
  end
  
  -- Check if diff is empty (common for empty commits or root)
  if diff_content:match("^%s*$") then
    if commit.empty then
      vim.notify(string.format("Commit %s is empty (no changes)", display_id), vim.log.levels.INFO)
    else
      vim.notify(string.format("No changes in commit %s", display_id), vim.log.levels.INFO)
    end
    return true
  end
  
  -- Create and display diff buffer
  local buf_id = create_diff_buffer(diff_content, display_id, format)
  local split_direction = config.get('diff.split') or 'horizontal'
  local diff_win = display_diff_buffer(buf_id, split_direction)
  
  vim.notify(string.format("Showing %s diff for commit %s", format, display_id), vim.log.levels.INFO)
  return true
end

-- Show diff summary (--stat) for the specified commit
M.show_diff_summary = function(commit, options)
  return M.show_diff(commit, 'stat', options)
end

return M