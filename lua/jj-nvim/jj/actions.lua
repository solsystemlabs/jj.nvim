local M = {}

-- Import all command modules
local commit = require('jj-nvim.jj.commit')
local squash = require('jj-nvim.jj.squash')
local split = require('jj-nvim.jj.split')
local rebase = require('jj-nvim.jj.rebase')
local diff = require('jj-nvim.jj.diff')
local status = require('jj-nvim.jj.status')
local git = require('jj-nvim.jj.git')
local edit = require('jj-nvim.jj.edit')
local abandon = require('jj-nvim.jj.abandon')
local new = require('jj-nvim.jj.new')
local describe = require('jj-nvim.jj.describe')

-- Common utilities
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

-- ============================================================================
-- Edit Operations
-- ============================================================================

-- Edit the specified commit
M.edit_commit = edit.edit_commit

-- Get a user-friendly description of what the edit command will do
M.get_edit_description = edit.get_edit_description

-- ============================================================================
-- Abandon Operations
-- ============================================================================

-- Abandon the specified commit
M.abandon_commit = abandon.abandon_commit

-- Abandon multiple commits
M.abandon_multiple_commits = abandon.abandon_multiple_commits

-- ============================================================================
-- New Change Operations
-- ============================================================================

-- Create a new child change from the specified parent commit
M.new_child = new.new_child

-- Get a user-friendly description of what the new child command will do
M.get_new_child_description = new.get_new_child_description

-- Create a new change after the specified commit (sibling)
M.new_after = new.new_after

-- Create a new change before the specified commit (insert)
M.new_before = new.new_before

-- Create a new change with multiple parents using change IDs directly
M.new_with_change_ids = new.new_with_change_ids

-- Create a simple new change (jj new)
M.new_simple = new.new_simple

-- ============================================================================
-- Diff Operations
-- ============================================================================

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
  local diff_content, diff_err = diff.get_diff(change_id, diff_options)
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

-- ============================================================================
-- Git Operations
-- ============================================================================

-- Git fetch operation
M.git_fetch = function(options)
  options = options or {}

  vim.notify("Fetching from remote...", vim.log.levels.INFO)

  local result, err = git.git_fetch(options)
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
  local commands = require('jj-nvim.jj.commands')
  local current_branch = commands.get_current_branch()
  local branch_info = current_branch and string.format(" (%s)", current_branch) or ""

  vim.notify(string.format("Pushing to remote%s...", branch_info), vim.log.levels.INFO)

  local result, err = git.git_push(options)
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

-- ============================================================================
-- Status Operations
-- ============================================================================

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

  local status_content, err = status.get_status(options)
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

-- ============================================================================
-- Description Operations
-- ============================================================================

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

    local result, exec_err = describe.describe(change_id, new_description)

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

-- ============================================================================
-- Commit Operations
-- ============================================================================

-- Commit working copy changes
M.commit_working_copy = commit.commit_working_copy

-- Show commit options menu
M.show_commit_menu = commit.show_commit_menu

-- Handle commit menu selection
M.handle_commit_menu_selection = commit.handle_commit_menu_selection

-- ============================================================================
-- Squash Operations
-- ============================================================================

-- Squash current commit into target commit
M.squash_into_commit = squash.squash_into_commit

-- Squash current commit into bookmark target
M.squash_into_bookmark = squash.squash_into_bookmark

-- Show squash options menu after target selection
M.show_squash_options_menu = squash.show_squash_options_menu

-- Handle squash options menu selection
M.handle_squash_options_selection = squash.handle_squash_options_selection

-- ============================================================================
-- Split Operations
-- ============================================================================

-- Split the specified commit
M.split_commit = split.split_commit

-- Show split options menu
M.show_split_options_menu = split.show_split_options_menu

-- Handle split options menu selection
M.handle_split_options_selection = split.handle_split_options_selection

-- ============================================================================
-- Rebase Operations
-- ============================================================================

-- Rebase multiple commits (for revisions mode)
M.rebase_multiple_commits = rebase.rebase_multiple_commits

-- Rebase the specified commit
M.rebase_commit = rebase.rebase_commit

-- Show rebase options menu
M.show_rebase_options_menu = rebase.show_rebase_options_menu

-- Handle rebase options menu selection
M.handle_rebase_options_selection = rebase.handle_rebase_options_selection

return M