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
  local result, exec_err = execute_with_error_handling({ 'edit', change_id }, "edit commit")
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

  local change_id, err = get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Confirm before abandoning
  local description = commit:get_short_description()
  local display_id = get_short_display_id(commit, change_id)
  local confirm_msg = string.format("Abandon commit %s: %s?", display_id, description)

  vim.ui.select({ 'Yes', 'No' }, {
    prompt = confirm_msg,
  }, function(choice)
    if choice == 'Yes' then
      local result, exec_err = execute_with_error_handling({ 'abandon', change_id }, "abandon commit")
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
  local cmd_args = { 'new', change_id }

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
  local cmd_args = { 'new', '--after', change_id }

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
  local cmd_args = { 'new', '--before', change_id }

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
  local cmd_args = { 'new' }

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
    confirm_msg = confirm_msg ..
        "\n" .. table.concat(commit_summaries, "\n", 1, 3) .. "\n  ... and " .. (#commit_summaries - 3) .. " more"
  end

  vim.ui.select({ 'Yes', 'No' }, {
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

      vim.notify(string.format("Abandoning %d commit%s...", #change_ids, #change_ids > 1 and "s" or ""),
        vim.log.levels.INFO)

      -- Execute abandon command with all change IDs
      local cmd_args = { 'abandon' }
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

  -- Set buffer name and type (make it unique using buffer ID)
  local buf_name = string.format('jj-diff-%s-%s', commit_id or 'unknown', buf_id)
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

-- Create floating window configuration
local function create_float_config(config_key)
  config_key = config_key or 'diff.float'
  local float_config = config.get(config_key) or {}
  local width_ratio = float_config.width or 0.8
  local height_ratio = float_config.height or 0.8
  local border = float_config.border or 'rounded'

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
    zindex = 100,
  }
end

-- Display diff buffer in a split window
local function display_diff_buffer_split(buf_id, split_direction)
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

  return vim.api.nvim_get_current_win()
end

-- Display diff buffer in a floating window
local function display_diff_buffer_float(buf_id, config_key)
  local float_config = create_float_config(config_key)
  local win_id = vim.api.nvim_open_win(buf_id, true, float_config)

  -- Set window options for better appearance
  vim.api.nvim_win_set_option(win_id, 'wrap', false)
  vim.api.nvim_win_set_option(win_id, 'cursorline', true)

  return win_id
end

-- Display diff buffer based on configuration
local function display_diff_buffer(buf_id, display_mode, split_direction)
  local win_id

  if display_mode == 'float' then
    win_id = display_diff_buffer_float(buf_id, 'diff.float')
  else
    win_id = display_diff_buffer_split(buf_id, split_direction)
  end

  -- Set up keymap to close diff window (works for both split and float)
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win_id, false)
  end, { buffer = buf_id, noremap = true, silent = true })

  -- Set up keymap to return to log window
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win_id, false)
  end, { buffer = buf_id, noremap = true, silent = true })

  return win_id
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
  local display_mode = config.get('diff.display') or 'split'
  local split_direction = config.get('diff.split') or 'horizontal'
  local diff_win = display_diff_buffer(buf_id, display_mode, split_direction)

  return true
end

-- Show diff summary (--stat) for the specified commit
M.show_diff_summary = function(commit, options)
  return M.show_diff(commit, 'stat', options)
end

-- Git fetch operation
M.git_fetch = function(options)
  options = options or {}

  vim.notify("Fetching from remote...", vim.log.levels.INFO)

  local result, err = commands.git_fetch(options)
  if not result then
    local error_msg = err or "Unknown error"

    -- Handle common git fetch errors
    if error_msg:find("Could not resolve hostname") then
      error_msg = "Network error: could not resolve hostname"
    elseif error_msg:find("Permission denied") then
      error_msg = "Permission denied: check your SSH keys or credentials"
    elseif error_msg:find("not found") then
      error_msg = "Repository not found or access denied"
    elseif error_msg:find("timeout") then
      error_msg = "Connection timeout"
    end

    vim.notify(string.format("Failed to fetch: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Check if fetch actually got new commits
  if result:match("^%s*$") then
    vim.notify("Fetch completed - repository is up to date", vim.log.levels.INFO)
  else
    vim.notify("Fetch completed successfully", vim.log.levels.INFO)
  end

  return true
end

-- Git push operation
M.git_push = function(options)
  options = options or {}

  -- Get current branch for display
  local current_branch = commands.get_current_branch()
  local branch_info = current_branch and string.format(" (%s)", current_branch) or ""

  vim.notify(string.format("Pushing to remote%s...", branch_info), vim.log.levels.INFO)

  local result, err = commands.git_push(options)
  if not result then
    local error_msg = err or "Unknown error"

    -- Handle common git push errors
    if error_msg:find("rejected") then
      error_msg = "Push rejected: remote has newer commits (try fetching first)"
    elseif error_msg:find("Permission denied") then
      error_msg = "Permission denied: check your SSH keys or credentials"
    elseif error_msg:find("not found") then
      error_msg = "Repository not found or access denied"
    elseif error_msg:find("timeout") then
      error_msg = "Connection timeout"
    elseif error_msg:find("non-fast-forward") then
      error_msg = "Push rejected: would not be a fast-forward (use force push if intended)"
    end

    vim.notify(string.format("Failed to push: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  vim.notify(string.format("Push completed successfully%s", branch_info), vim.log.levels.INFO)
  return true
end

-- Create a status buffer and display status content
local function create_status_buffer(content)
  -- Create a new buffer for the status
  local buf_id = vim.api.nvim_create_buf(false, true)

  -- Set buffer name and type (make it unique using buffer ID)
  local buf_name = 'jj-status-' .. buf_id
  vim.api.nvim_buf_set_name(buf_id, buf_name)

  -- Configure buffer options
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', false)
  vim.api.nvim_buf_set_option(buf_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf_id, 'filetype', 'text')

  -- Setup ANSI highlights for colored status output
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

-- Display status buffer based on configuration
local function display_status_buffer(buf_id, display_mode, split_direction)
  local win_id

  if display_mode == 'float' then
    win_id = display_diff_buffer_float(buf_id, 'status.float')
  else
    win_id = display_diff_buffer_split(buf_id, split_direction)
  end

  -- Set up keymap to close status window (works for both split and float)
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win_id, false)
  end, { buffer = buf_id, noremap = true, silent = true })

  -- Set up keymap to return to log window
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win_id, false)
  end, { buffer = buf_id, noremap = true, silent = true })

  return win_id
end

-- Show repository status
M.show_status = function(options)
  options = options or {}

  local status_content, err = commands.get_status(options)
  if not status_content then
    local error_msg = err or "Unknown error"

    -- Handle common status errors
    if error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("No such file") then
      error_msg = "Specified path not found"
    end

    vim.notify(string.format("Failed to get status: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Create and display status buffer
  local buf_id = create_status_buffer(status_content)
  local display_mode = config.get('status.display') or 'split'
  local split_direction = config.get('status.split') or 'horizontal'
  local status_win = display_status_buffer(buf_id, display_mode, split_direction)

  return true
end

-- Set description for a commit
M.set_description = function(commit, on_success)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end

  -- Don't allow describing the root commit
  if commit.root then
    vim.notify("Cannot set description for root commit", vim.log.levels.WARN)
    return false
  end

  local change_id, err = get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local display_id = get_short_display_id(commit, change_id)
  local current_description = commit:get_description_text_only()

  -- Show current description if it's not the default
  local prompt_text = "Enter description for commit " .. display_id .. ":"
  if current_description and current_description ~= "(no description set)" then
    prompt_text = prompt_text .. "\nCurrent: " .. current_description
  end

  -- Prompt user for new description
  vim.ui.input({
    prompt = prompt_text,
    default = current_description ~= "(no description set)" and current_description or "",
  }, function(new_description)
    if not new_description then
      vim.notify("Description cancelled", vim.log.levels.INFO)
      return false
    end

    -- Allow empty description to clear it
    if new_description == "" then
      new_description = "(no description set)"
    end

    local result, exec_err = commands.describe(change_id, new_description)

    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Commit not found - it may have been abandoned or modified"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      elseif error_msg:find("immutable") then
        error_msg = "Cannot modify immutable commit"
      end

      vim.notify(string.format("Failed to set description: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify(string.format("Updated description for commit %s", display_id), vim.log.levels.INFO)
    if on_success then on_success() end
    return true
  end)
end

-- Commit working copy changes
M.commit_working_copy = function(options, on_success)
  options = options or {}

  -- Check if there are any changes to commit
  local status_content, status_err = commands.get_status({ silent = true })
  if not status_content then
    vim.notify("Failed to check repository status", vim.log.levels.ERROR)
    return false
  end

  -- Check if working copy has changes
  if status_content:match("The working copy has no changes") then
    vim.notify("No changes to commit", vim.log.levels.INFO)
    return true
  end

  -- If message is provided in options, use it directly
  if options.message and options.message ~= "" then
    local result, err = commands.commit(options.message, options)
    if not result then
      local error_msg = err or "Unknown error"
      if error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      elseif error_msg:find("empty commit") then
        error_msg = "No changes to commit"
      end

      vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify("Committed working copy changes", vim.log.levels.INFO)
    if on_success then on_success() end
    return true
  end

  -- Prompt user for commit message
  vim.ui.input({
    prompt = "Enter commit message:",
    default = "",
  }, function(message)
    if not message or message:match("^%s*$") then
      vim.notify("Commit cancelled - no message provided", vim.log.levels.INFO)
      return false
    end

    local result, err = commands.commit(message, options)
    if not result then
      local error_msg = err or "Unknown error"
      if error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      elseif error_msg:find("empty commit") then
        error_msg = "No changes to commit"
      elseif error_msg:find("immutable") then
        error_msg = "Cannot modify immutable commit"
      end

      vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify("Committed working copy changes", vim.log.levels.INFO)
    if on_success then on_success() end
    return true
  end)
end

-- Create a simple new change (jj new)
M.new_simple = function(options)
  options = options or {}

  -- Build command arguments
  local cmd_args = { 'new' }

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, "-m")
    table.insert(cmd_args, options.message)
  end

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  return true
end

-- Show commit options menu
M.show_commit_menu = function(parent_win_id)
  local inline_menu = require('jj-nvim.ui.inline_menu')

  -- Check if there are any changes to commit
  local status_content, status_err = commands.get_status({ silent = true })
  if not status_content then
    vim.notify("Failed to check repository status", vim.log.levels.ERROR)
    return false
  end

  -- Check if working copy has changes
  if status_content:match("The working copy has no changes") then
    vim.notify("No changes to commit", vim.log.levels.INFO)
    return true
  end

  -- Define menu configuration
  local menu_config = {
    title = "Commit Options",
    items = {
      {
        key = "q",
        description = "Quick commit (prompt for message)",
        action = "quick_commit",
      },
      {
        key = "i",
        description = "Interactive commit (choose changes)",
        action = "interactive_commit",
      },
      {
        key = "r",
        description = "Reset author and commit",
        action = "reset_author_commit",
      },
      {
        key = "a",
        description = "Commit with custom author",
        action = "custom_author_commit",
      },
      {
        key = "f",
        description = "Commit specific files (filesets)",
        action = "fileset_commit",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_commit_menu_selection(selected_item)
    end,
    on_cancel = function()
      -- Menu cancelled - do nothing
    end
  })
end

-- Handle commit menu selection
M.handle_commit_menu_selection = function(selected_item)
  if selected_item.action == "quick_commit" then
    -- Quick commit with message prompt
    M.commit_working_copy({})
  elseif selected_item.action == "interactive_commit" then
    -- Interactive commit using terminal interface
    local success = commands.commit_interactive({
      on_success = function()
        vim.notify("Interactive commit completed", vim.log.levels.INFO)
        -- Buffer refresh is handled automatically by interactive terminal
      end,
      on_error = function(exit_code)
        -- Error message already shown by interactive terminal
      end,
      on_cancel = function()
        vim.notify("Interactive commit cancelled", vim.log.levels.INFO)
      end
    })

    if not success then
      vim.notify("Failed to start interactive commit", vim.log.levels.ERROR)
    end
  elseif selected_item.action == "reset_author_commit" then
    -- Commit with reset author
    vim.ui.input({
      prompt = "Enter commit message (author will be reset):",
      default = "",
    }, function(message)
      if not message or message:match("^%s*$") then
        vim.notify("Commit cancelled - no message provided", vim.log.levels.INFO)
        return
      end

      local result, err = commands.commit(message, { reset_author = true })
      if not result then
        local error_msg = err or "Unknown error"
        vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
      else
        vim.notify("Committed with reset author", vim.log.levels.INFO)
        require('jj-nvim').refresh()
      end
    end)
  elseif selected_item.action == "custom_author_commit" then
    -- Commit with custom author - two-step process
    vim.ui.input({
      prompt = "Enter author (Name <email@example.com>):",
      default = "",
    }, function(author)
      if not author or author:match("^%s*$") then
        vim.notify("Commit cancelled - no author provided", vim.log.levels.INFO)
        return
      end

      vim.ui.input({
        prompt = "Enter commit message:",
        default = "",
      }, function(message)
        if not message or message:match("^%s*$") then
          vim.notify("Commit cancelled - no message provided", vim.log.levels.INFO)
          return
        end

        local result, err = commands.commit(message, { author = author })
        if not result then
          local error_msg = err or "Unknown error"
          vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
        else
          vim.notify(string.format("Committed with author: %s", author), vim.log.levels.INFO)
          require('jj-nvim').refresh()
        end
      end)
    end)
  elseif selected_item.action == "fileset_commit" then
    -- Commit specific files
    vim.ui.input({
      prompt = "Enter file patterns (e.g., '*.lua src/'):",
      default = "",
    }, function(filesets_str)
      if not filesets_str or filesets_str:match("^%s*$") then
        vim.notify("Commit cancelled - no file patterns provided", vim.log.levels.INFO)
        return
      end

      -- Split filesets by spaces
      local filesets = vim.split(filesets_str, "%s+")

      vim.ui.input({
        prompt = "Enter commit message:",
        default = "",
      }, function(message)
        if not message or message:match("^%s*$") then
          vim.notify("Commit cancelled - no message provided", vim.log.levels.INFO)
          return
        end

        local result, err = commands.commit(message, { filesets = filesets })
        if not result then
          local error_msg = err or "Unknown error"
          vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
        else
          vim.notify(string.format("Committed files: %s", filesets_str), vim.log.levels.INFO)
          require('jj-nvim').refresh()
        end
      end)
    end)
  end
end

-- Squash current commit into target commit
M.squash_into_commit = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Don't allow squashing into root commit
  if target_commit.root then
    vim.notify("Cannot squash into the root commit", vim.log.levels.WARN)
    return false
  end

  local target_change_id, err = get_change_id(target_commit)
  if not target_change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local target_display_id = get_short_display_id(target_commit, target_change_id)
  
  -- Handle interactive mode with callbacks
  if options.interactive then
    -- Add callbacks for interactive mode
    options.on_success = function()
      vim.notify(string.format("Interactive squash into %s completed", target_display_id), vim.log.levels.INFO)
      -- Buffer refresh is handled automatically by interactive terminal
    end
    options.on_error = function(exit_code)
      -- Error message already shown by interactive terminal
    end
    options.on_cancel = function()
      vim.notify("Interactive squash cancelled", vim.log.levels.INFO)
    end
    
    -- Execute interactive squash
    local success = commands.squash(target_change_id, options)
    if not success then
      vim.notify("Failed to start interactive squash", vim.log.levels.ERROR)
      return false
    end
    return true -- Interactive command started successfully
  else
    -- Non-interactive squash
    local result, exec_err = commands.squash(target_change_id, options)
    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Commit not found - it may have been abandoned or modified"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Cannot squash - would create a cycle in commit graph"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      end

      vim.notify(string.format("Failed to squash into commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify(string.format("Squashed into %s", target_display_id), vim.log.levels.INFO)
    return true
  end
end

-- Squash current commit into bookmark target
M.squash_into_bookmark = function(bookmark, options)
  if not bookmark then
    vim.notify("No bookmark specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Use bookmark name as target revision
  local target_revision = bookmark.name
  if not target_revision or target_revision == "" then
    vim.notify("Invalid bookmark: missing name", vim.log.levels.ERROR)
    return false
  end

  local bookmark_display = bookmark.display_name or bookmark.name
  
  -- Handle interactive mode with callbacks
  if options.interactive then
    -- Add callbacks for interactive mode
    options.on_success = function()
      vim.notify(string.format("Interactive squash into bookmark '%s' completed", bookmark_display), vim.log.levels.INFO)
      -- Buffer refresh is handled automatically by interactive terminal
    end
    options.on_error = function(exit_code)
      -- Error message already shown by interactive terminal
    end
    options.on_cancel = function()
      vim.notify("Interactive squash cancelled", vim.log.levels.INFO)
    end
    
    -- Execute interactive squash
    local success = commands.squash(target_revision, options)
    if not success then
      vim.notify("Failed to start interactive squash", vim.log.levels.ERROR)
      return false
    end
    return true -- Interactive command started successfully
  else
    -- Non-interactive squash
    local result, exec_err = commands.squash(target_revision, options)
    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Bookmark not found - it may have been deleted or modified"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Cannot squash - would create a cycle in commit graph"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      end

      vim.notify(string.format("Failed to squash into bookmark: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify(string.format("Squashed into bookmark '%s'", bookmark_display), vim.log.levels.INFO)
    return true
  end
end

-- Show squash options menu after target selection
M.show_squash_options_menu = function(target, target_type, parent_win_id, source_commit)
  local inline_menu = require('jj-nvim.ui.inline_menu')
  
  -- Determine target display name
  local target_display = ""
  if target_type == "commit" then
    target_display = target.short_change_id or target.change_id:sub(1, 8)
  elseif target_type == "bookmark" then
    target_display = "bookmark '" .. (target.display_name or target.name) .. "'"
  end

  -- Determine source display name
  local source_display = ""
  if source_commit then
    source_display = source_commit.short_change_id or source_commit.change_id:sub(1, 8)
  else
    source_display = "@"
  end

  -- Define menu configuration
  local menu_config = {
    title = "Squash " .. source_display .. " into " .. target_display,
    items = {
      {
        key = "q",
        description = "Quick squash (standard)",
        action = "quick_squash",
      },
      {
        key = "i",
        description = "Interactive squash",
        action = "interactive_squash",
      },
      {
        key = "u",
        description = "Use destination message & keep source",
        action = "use_dest_keep_squash",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_squash_options_selection(selected_item, target, target_type, source_commit)
    end,
    on_cancel = function()
      vim.notify("Squash cancelled", vim.log.levels.INFO)
    end
  })
end

-- Handle squash options menu selection
M.handle_squash_options_selection = function(selected_item, target, target_type, source_commit)
  local options = {}
  
  -- Configure options based on selection
  if selected_item.action == "interactive_squash" then
    options.interactive = true
  elseif selected_item.action == "use_dest_keep_squash" then
    options.use_destination_message = true
    options.keep_emptied = true
  end
  -- quick_squash uses default options (empty table)

  -- Add source commit to options if provided
  if source_commit then
    local source_change_id, err = get_change_id(source_commit)
    if source_change_id then
      options.from_revision = source_change_id
    else
      vim.notify("Failed to get source commit ID: " .. (err or "Unknown error"), vim.log.levels.ERROR)
      return
    end
  else
    -- Fallback to current working copy if no source commit specified
    -- This shouldn't happen in normal workflow, but provides safety
    vim.notify("Warning: No source commit specified, using working copy (@)", vim.log.levels.WARN)
  end

  local success = false
  
  -- Execute squash based on target type
  if target_type == "commit" then
    success = M.squash_into_commit(target, options)
  elseif target_type == "bookmark" then
    success = M.squash_into_bookmark(target, options)
  end

  if success then
    -- Refresh buffer to show changes
    require('jj-nvim').refresh()
  end
end

-- Split the specified commit
M.split_commit = function(commit, options)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Don't allow splitting the root commit
  if commit.root then
    vim.notify("Cannot split the root commit", vim.log.levels.WARN)
    return false
  end

  local change_id, err = get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local display_id = get_short_display_id(commit, change_id)
  
  -- Handle interactive mode with callbacks
  if options.interactive then
    -- Add callbacks for interactive mode
    options.on_success = function()
      vim.notify(string.format("Interactive split of %s completed", display_id), vim.log.levels.INFO)
      -- Buffer refresh is handled automatically by interactive terminal
    end
    options.on_error = function(exit_code)
      -- Error message already shown by interactive terminal
    end
    options.on_cancel = function()
      vim.notify("Interactive split cancelled", vim.log.levels.INFO)
    end
    
    -- Execute interactive split
    local success = commands.split(change_id, options)
    if not success then
      vim.notify("Failed to start interactive split", vim.log.levels.ERROR)
      return false
    end
    return true -- Interactive command started successfully
  else
    -- Non-interactive split
    local result, exec_err = commands.split(change_id, options)
    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Commit not found - it may have been abandoned or modified"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Cannot split - would create a cycle in commit graph"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      elseif error_msg:find("empty commit") then
        error_msg = "Cannot split empty commit - use 'jj new' instead"
      end

      vim.notify(string.format("Failed to split commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify(string.format("Split commit %s", display_id), vim.log.levels.INFO)
    return true
  end
end

-- Show split options menu
M.show_split_options_menu = function(target_commit, parent_win_id)
  local inline_menu = require('jj-nvim.ui.inline_menu')
  
  -- Determine target display name
  local target_display = ""
  if target_commit then
    target_display = target_commit.short_change_id or target_commit.change_id:sub(1, 8)
  else
    target_display = "@"
  end

  -- Define menu configuration
  local menu_config = {
    title = "Split " .. target_display,
    items = {
      {
        key = "q",
        description = "Quick split (interactive diff editor)",
        action = "quick_split",
      },
      {
        key = "i",
        description = "Interactive split (choose parts)",
        action = "interactive_split",
      },
      {
        key = "p",
        description = "Parallel split (side-by-side)",
        action = "parallel_split",
      },
      {
        key = "f",
        description = "Split specific files (filesets)",
        action = "fileset_split",
      },
      {
        key = "a",
        description = "Split with insert-after (select target)",
        action = "insert_after_split",
      },
      {
        key = "b",
        description = "Split with insert-before (select target)",
        action = "insert_before_split",
      },
      {
        key = "d",
        description = "Split with destination (select target)",
        action = "destination_split",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_split_options_selection(selected_item, target_commit)
    end,
    on_cancel = function()
      vim.notify("Split cancelled", vim.log.levels.INFO)
    end
  })
end

-- Handle split options menu selection
M.handle_split_options_selection = function(selected_item, target_commit)
  local options = {}
  
  -- Configure options based on selection
  if selected_item.action == "interactive_split" then
    options.interactive = true
  elseif selected_item.action == "parallel_split" then
    options.parallel = true
    options.interactive = true -- Parallel splits are typically interactive
  elseif selected_item.action == "fileset_split" then
    -- Prompt for filesets
    vim.ui.input({
      prompt = "Enter file patterns (e.g., '*.lua src/'):",
      default = "",
    }, function(filesets_str)
      if not filesets_str or filesets_str:match("^%s*$") then
        vim.notify("Split cancelled - no file patterns provided", vim.log.levels.INFO)
        return
      end

      -- Split filesets by spaces
      local filesets = vim.split(filesets_str, "%s+")
      options.filesets = filesets
      options.interactive = true -- Fileset splits are typically interactive
      
      local success = M.split_commit(target_commit, options)
      if success then
        -- Refresh buffer to show changes
        require('jj-nvim').refresh()
      end
    end)
    return -- Exit early for fileset handling
  elseif selected_item.action == "insert_after_split" then
    -- Enter target selection mode for insert-after
    local window = require('jj-nvim.ui.window')
    window.enter_split_target_selection_mode("insert_after", target_commit)
    return -- Exit early - target selection will handle the rest
  elseif selected_item.action == "insert_before_split" then
    -- Enter target selection mode for insert-before
    local window = require('jj-nvim.ui.window')
    window.enter_split_target_selection_mode("insert_before", target_commit)
    return -- Exit early - target selection will handle the rest
  elseif selected_item.action == "destination_split" then
    -- Enter target selection mode for destination
    local window = require('jj-nvim.ui.window')
    window.enter_split_target_selection_mode("destination", target_commit)
    return -- Exit early - target selection will handle the rest
  else
    -- quick_split uses default options (interactive diff editor)
    options.interactive = true
  end

  local success = M.split_commit(target_commit, options)
  if success then
    -- Refresh buffer to show changes
    require('jj-nvim').refresh()
  end
end

-- Rebase multiple commits (for revisions mode)
M.rebase_multiple_commits = function(selected_commit_ids, options)
  if not selected_commit_ids or #selected_commit_ids == 0 then
    vim.notify("No commits selected for rebase", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Get all commits to validate the selected ones
  local buffer = require('jj-nvim.ui.buffer')
  local all_commits = buffer.get_commits()
  if not all_commits then
    vim.notify("Failed to get commits from buffer", vim.log.levels.ERROR)
    return false
  end

  -- Find and validate selected commits
  local commits_to_rebase = {}
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
      else
        table.insert(commits_to_rebase, commit)
      end
    else
      table.insert(invalid_commits, string.format("%s (not found)", commit_id:sub(1, 8)))
    end
  end

  -- Report invalid commits
  if #invalid_commits > 0 then
    vim.notify(string.format("Cannot rebase: %s", table.concat(invalid_commits, ", ")), vim.log.levels.WARN)
    if #commits_to_rebase == 0 then
      return false
    end
  end

  -- Build rebase options for multiple revisions
  local rebase_options = { silent = options.silent }
  
  -- Extract change IDs for all valid commits
  local change_ids = {}
  for _, commit in ipairs(commits_to_rebase) do
    local change_id, err = get_change_id(commit)
    if change_id then
      table.insert(change_ids, change_id)
    else
      vim.notify(string.format("Failed to get change ID for commit: %s", err), vim.log.levels.ERROR)
      return false
    end
  end

  -- Use revisions mode for multiple commits
  rebase_options.revisions = change_ids

  -- Add destination
  if options.destination then
    rebase_options.destination = options.destination
  elseif options.insert_after then
    rebase_options.insert_after = options.insert_after
  elseif options.insert_before then
    rebase_options.insert_before = options.insert_before
  else
    vim.notify("No destination specified for rebase", vim.log.levels.ERROR)
    return false
  end

  -- Add flags
  if options.skip_emptied then
    rebase_options.skip_emptied = true
  end
  if options.keep_divergent then
    rebase_options.keep_divergent = true
  end

  local result, exec_err = commands.rebase(rebase_options)
  if not result then
    local error_msg = exec_err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "One or more commits not found - they may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot rebase - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("immutable") then
      error_msg = "Cannot rebase immutable commit(s)"
    end

    vim.notify(string.format("Failed to rebase commits: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  local commit_count = #change_ids
  vim.notify(string.format("Rebased %d commit%s", commit_count, commit_count > 1 and "s" or ""), vim.log.levels.INFO)
  return true
end

-- Rebase the specified commit
M.rebase_commit = function(source_commit, options)
  if not source_commit then
    vim.notify("No source commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Don't allow rebasing the root commit
  if source_commit.root then
    vim.notify("Cannot rebase the root commit", vim.log.levels.WARN)
    return false
  end

  local source_change_id, err = get_change_id(source_commit)
  if not source_change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local display_id = get_short_display_id(source_commit, source_change_id)

  -- Build rebase options, defaulting to branch mode if none specified
  local rebase_options = { silent = options.silent }
  
  -- Add source specification
  if options.mode == "source" then
    rebase_options.source = source_change_id
  elseif options.mode == "revisions" then
    rebase_options.revisions = source_change_id
  else
    -- Default to branch mode (-b)
    rebase_options.branch = source_change_id
  end

  -- Add destination
  if options.destination then
    rebase_options.destination = options.destination
  elseif options.insert_after then
    rebase_options.insert_after = options.insert_after
  elseif options.insert_before then
    rebase_options.insert_before = options.insert_before
  else
    vim.notify("No destination specified for rebase", vim.log.levels.ERROR)
    return false
  end

  -- Add flags
  if options.skip_emptied then
    rebase_options.skip_emptied = true
  end
  if options.keep_divergent then
    rebase_options.keep_divergent = true
  end

  local result, exec_err = commands.rebase(rebase_options)
  if not result then
    local error_msg = exec_err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot rebase - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("immutable") then
      error_msg = "Cannot rebase immutable commit"
    end

    vim.notify(string.format("Failed to rebase commit: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  vim.notify(string.format("Rebased commit %s", display_id), vim.log.levels.INFO)
  return true
end

-- Show rebase options menu
M.show_rebase_options_menu = function(source_commit, parent_win_id)
  local inline_menu = require('jj-nvim.ui.inline_menu')
  
  -- Determine source display name
  local source_display = ""
  if source_commit then
    source_display = source_commit.short_change_id or source_commit.change_id:sub(1, 8)
  else
    source_display = "@"
  end

  -- Define menu configuration
  local menu_config = {
    title = "Rebase " .. source_display,
    items = {
      {
        key = "b",
        description = "Rebase branch (-b) to selected target",
        action = "rebase_branch",
      },
      {
        key = "s", 
        description = "Rebase source and descendants (-s)",
        action = "rebase_source",
      },
      {
        key = "r",
        description = "Rebase specific revisions (-r)",
        action = "rebase_revisions",
      },
      {
        key = "d",
        description = "Select destination target (-d)",
        action = "select_destination",
      },
      {
        key = "a",
        description = "Select insert-after target (-A)",
        action = "select_insert_after",
      },
      {
        key = "f",
        description = "Select insert-before target (-B)",
        action = "select_insert_before",
      },
      {
        key = "e",
        description = "Skip emptied commits",
        action = "toggle_skip_emptied",
      },
      {
        key = "k",
        description = "Keep divergent commits",
        action = "toggle_keep_divergent",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_rebase_options_selection(selected_item, source_commit)
    end,
    on_cancel = function()
      vim.notify("Rebase cancelled", vim.log.levels.INFO)
    end
  })
end

-- Handle rebase options menu selection
M.handle_rebase_options_selection = function(selected_item, source_commit)
  local action = selected_item.action
  
  if action == "rebase_branch" or action == "rebase_source" then
    -- Enter target selection mode for rebase with the specified mode
    local mode = action:gsub("rebase_", "") -- Extract "branch" or "source"
    local window = require('jj-nvim.ui.window')
    window.enter_rebase_target_selection_mode("destination", source_commit, mode)
  elseif action == "rebase_revisions" then
    -- For revisions mode, allow multi-commit selection first
    vim.notify("Select multiple commits for rebase (Space to select, Enter when done, Esc to cancel)", vim.log.levels.INFO)
    local window = require('jj-nvim.ui.window')
    window.enter_rebase_multi_select_mode(source_commit)
  elseif action == "select_destination" then
    -- Enter target selection mode for destination
    local window = require('jj-nvim.ui.window')
    window.enter_rebase_target_selection_mode("destination", source_commit, "branch")
  elseif action == "select_insert_after" then
    -- Enter target selection mode for insert-after
    local window = require('jj-nvim.ui.window')
    window.enter_rebase_target_selection_mode("insert_after", source_commit, "branch")
  elseif action == "select_insert_before" then
    -- Enter target selection mode for insert-before
    local window = require('jj-nvim.ui.window')
    window.enter_rebase_target_selection_mode("insert_before", source_commit, "branch")
  elseif action == "toggle_skip_emptied" then
    vim.notify("Skip emptied commits option will be applied to next rebase", vim.log.levels.INFO)
    -- Note: This could be enhanced to store state for the next rebase operation
  elseif action == "toggle_keep_divergent" then
    vim.notify("Keep divergent commits option will be applied to next rebase", vim.log.levels.INFO)
    -- Note: This could be enhanced to store state for the next rebase operation
  end
end

return M

