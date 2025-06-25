local M = {}

-- Standard error handling for jj operations
M.handle_jj_error = function(err, operation_name, return_value)
  if err then
    vim.notify(
      string.format("Failed to %s: %s", operation_name, err),
      vim.log.levels.ERROR
    )
    return return_value
  end
  return nil
end

-- Handle nil/empty results with context
M.handle_empty_result = function(result, context_message, return_value)
  if not result or (type(result) == "table" and #result == 0) then
    vim.notify(context_message, vim.log.levels.ERROR)
    return return_value
  end
  return nil
end

-- Handle command execution results
M.handle_command_result = function(result, operation_name, opts)
  opts = opts or {}
  
  if result.code ~= 0 then
    if not opts.silent then
      vim.notify(
        string.format("%s failed: %s", operation_name, result.stderr or "Unknown error"),
        vim.log.levels.ERROR
      )
    end
    return nil, result.stderr
  end
  
  return result, nil
end

-- Handle protected call results
M.handle_pcall_result = function(success, result, operation_name, return_value)
  if not success then
    vim.notify(
      string.format("Failed to %s", operation_name),
      vim.log.levels.ERROR
    )
    return return_value
  end
  return result
end

-- Show informational messages with consistent formatting
M.show_info = function(message, ...)
  vim.notify(string.format(message, ...), vim.log.levels.INFO)
end

-- Show warning messages with consistent formatting
M.show_warning = function(message, ...)
  vim.notify(string.format(message, ...), vim.log.levels.WARN)
end

return M