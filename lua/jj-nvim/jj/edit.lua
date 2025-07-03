local M = {}

local command_utils = require('jj-nvim.jj.command_utils')

-- Edit the specified commit
M.edit_commit = function(commit)
  -- Validate commit
  local is_valid, err = command_utils.validate_commit(commit, { allow_root = false })
  if not is_valid then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  local change_id, change_err = command_utils.get_change_id(commit)
  if not change_id then
    vim.notify(change_err, vim.log.levels.ERROR)
    return false
  end

  local display_id = command_utils.get_short_display_id(commit, change_id)
  local result, exec_err = command_utils.execute_with_error_handling({ 'edit', change_id }, "edit commit")
  if not result then
    return false
  end

  vim.notify(string.format("Now editing commit %s", display_id), vim.log.levels.INFO)
  return true
end

-- Get a user-friendly description of what the edit command will do
M.get_edit_description = function(commit)
  local is_valid, err = command_utils.validate_commit(commit, { allow_root = false })
  if not is_valid then
    return err
  end

  local display_id = command_utils.get_short_display_id(commit)
  local description = commit:get_short_description()

  return string.format("Edit commit %s: %s", display_id, description)
end

return M