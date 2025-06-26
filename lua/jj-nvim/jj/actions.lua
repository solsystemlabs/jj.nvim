local M = {}

local commands = require('jj-nvim.jj.commands')
local buffer = require('jj-nvim.ui.buffer')

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

  -- Use change_id for jj edit command
  local change_id = commit.change_id or commit.short_change_id
  if not change_id or change_id == "" then
    vim.notify("Invalid commit: missing change ID", vim.log.levels.ERROR)
    return false
  end

  vim.notify(string.format("Editing commit %s...", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)

  -- Execute jj edit command
  local result, err = commands.execute({'edit', change_id})
  
  if not result then
    vim.notify(string.format("Failed to edit commit: %s", err or "Unknown error"), vim.log.levels.ERROR)
    return false
  end

  -- Success feedback
  vim.notify(string.format("Now editing commit %s", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  
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
M.abandon_commit = function(commit)
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

  local change_id = commit.change_id or commit.short_change_id
  if not change_id or change_id == "" then
    vim.notify("Invalid commit: missing change ID", vim.log.levels.ERROR)
    return false
  end

  -- Confirm before abandoning
  local description = commit:get_short_description()
  local confirm_msg = string.format("Abandon commit %s: %s? (y/N)", 
    commit.short_change_id or change_id:sub(1, 8), description)
  
  local choice = vim.fn.input(confirm_msg)
  if choice:lower() ~= 'y' and choice:lower() ~= 'yes' then
    vim.notify("Abandon cancelled", vim.log.levels.INFO)
    return false
  end

  vim.notify(string.format("Abandoning commit %s...", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)

  -- Execute jj abandon command
  local result, err = commands.execute({'abandon', change_id})
  
  if not result then
    vim.notify(string.format("Failed to abandon commit: %s", err or "Unknown error"), vim.log.levels.ERROR)
    return false
  end

  -- Success feedback
  vim.notify(string.format("Abandoned commit %s", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  
  return true
end

return M