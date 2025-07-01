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

return M