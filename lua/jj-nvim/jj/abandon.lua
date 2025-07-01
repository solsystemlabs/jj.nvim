local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_utils = require('jj-nvim.core.commit')

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
  local result, err = commands.execute_with_immutable_prompt(cmd_args)

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

-- Abandon multiple commits
M.abandon_multiple_commits = function(selected_commit_ids, on_success)
  if not selected_commit_ids or #selected_commit_ids == 0 then
    vim.notify("No commits selected for abandoning", vim.log.levels.WARN)
    return false
  end

  -- Get all commits to validate the selected ones
  local buffer = require('jj-nvim.ui.buffer')
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

return M