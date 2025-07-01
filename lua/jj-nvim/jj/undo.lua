local M = {}

local commands = require('jj-nvim.jj.commands')

-- Helper function to handle command execution with common error patterns
local function execute_with_error_handling(cmd_args, error_context)
  local result, err = commands.execute(cmd_args)

  if not result then
    local error_msg = err or "Unknown error"
    if error_msg:find("No operation to undo") then
      error_msg = "No operation to undo"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("Invalid revision") then
      error_msg = "Invalid revision specified"
    end

    vim.notify(string.format("Failed to %s: %s", error_context, error_msg), vim.log.levels.ERROR)
    return false, error_msg
  end

  return result, nil
end

-- Undo the last operation
M.undo_last = function(on_success)
  local result, err = execute_with_error_handling({ 'undo' }, "undo operation")
  if not result then
    return false
  end

  vim.notify("Undid last operation", vim.log.levels.INFO)
  if on_success then on_success() end
  return true
end

-- Undo a specific operation (for advanced usage)
M.undo_operation = function(operation_id, on_success)
  if not operation_id then
    vim.notify("No operation ID provided", vim.log.levels.WARN)
    return false
  end

  local result, err = execute_with_error_handling({ 'undo', operation_id }, "undo operation")
  if not result then
    return false
  end

  vim.notify(string.format("Undid operation %s", operation_id), vim.log.levels.INFO)
  if on_success then on_success() end
  return true
end

return M