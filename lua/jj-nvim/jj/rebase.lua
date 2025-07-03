local M = {}

local command_utils = require('jj-nvim.jj.command_utils')
local commands = require('jj-nvim.jj.commands')

-- Rebase operation
M.rebase = function(options)
  if not options or not (options.destination or options.insert_after or options.insert_before) then
    return nil, "No rebase target specified (destination, insert_after, or insert_before required)"
  end

  options = options or {}
  local cmd_args = { 'rebase' }

  -- Add source selection options (only one should be specified)
  if options.branch then
    table.insert(cmd_args, '-b')
    if type(options.branch) == 'table' then
      for _, branch in ipairs(options.branch) do
        table.insert(cmd_args, branch)
      end
    else
      table.insert(cmd_args, options.branch)
    end
  elseif options.source then
    table.insert(cmd_args, '-s')
    if type(options.source) == 'table' then
      for _, source in ipairs(options.source) do
        table.insert(cmd_args, source)
      end
    else
      table.insert(cmd_args, options.source)
    end
  elseif options.revisions then
    table.insert(cmd_args, '-r')
    if type(options.revisions) == 'table' then
      for _, revision in ipairs(options.revisions) do
        table.insert(cmd_args, revision)
      end
    else
      table.insert(cmd_args, options.revisions)
    end
  end
  -- If none specified, jj rebase defaults to -b @

  -- Add destination options (only one should be specified)
  if options.destination then
    table.insert(cmd_args, '-d')
    if type(options.destination) == 'table' then
      for _, dest in ipairs(options.destination) do
        table.insert(cmd_args, dest)
      end
    else
      table.insert(cmd_args, options.destination)
    end
  elseif options.insert_after then
    table.insert(cmd_args, '-A')
    if type(options.insert_after) == 'table' then
      for _, after in ipairs(options.insert_after) do
        table.insert(cmd_args, after)
      end
    else
      table.insert(cmd_args, options.insert_after)
    end
  elseif options.insert_before then
    table.insert(cmd_args, '-B')
    if type(options.insert_before) == 'table' then
      for _, before in ipairs(options.insert_before) do
        table.insert(cmd_args, before)
      end
    else
      table.insert(cmd_args, options.insert_before)
    end
  end

  -- Add additional flags
  if options.skip_emptied then
    table.insert(cmd_args, '--skip-emptied')
  end

  if options.keep_divergent then
    table.insert(cmd_args, '--keep-divergent')
  end

  return commands.execute_with_immutable_prompt(cmd_args, { silent = options.silent })
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

  local result, exec_err = M.rebase(rebase_options)
  if not result then
    local error_msg = exec_err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "One or more commits not found - they may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot rebase - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
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

  local result, exec_err = M.rebase(rebase_options)
  if not result then
    local error_msg = exec_err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot rebase - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
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
    vim.notify("Select multiple commits for rebase (Space to select, Enter when done, Esc to cancel)",
      vim.log.levels.INFO)
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
  end
end

return M