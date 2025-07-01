local M = {}

M.execute = function(args, opts)
  opts = opts or {}
  local cmd = { 'jj' }

  if type(args) == 'string' then
    args = vim.split(args, ' ', { plain = true })
  end

  for _, arg in ipairs(args) do
    table.insert(cmd, arg)
  end

  local result = vim.system(cmd, { text = true }):wait(3000) -- 3 second timeout

  -- Handle timeout case where result is nil
  if not result then
    local error_msg = 'jj command timed out after 3 seconds'
    if not opts.silent then
      vim.notify(error_msg, vim.log.levels.ERROR)
    end
    return nil, error_msg
  end

  if result.code ~= 0 then
    if not opts.silent then
      vim.notify('jj command failed: ' .. (result.stderr or 'Unknown error'), vim.log.levels.ERROR)
    end
    return nil, result.stderr
  end

  return result.stdout, nil
end

M.is_jj_repo = function()
  local result, _ = M.execute('root', { silent = true })
  return result ~= nil
end

M.get_current_branch = function()
  local result, err = M.execute('branch list', { silent = true })
  if not result then
    return nil
  end

  for line in result:gmatch('[^\r\n]+') do
    if line:match('%*') then
      return line:match('%* ([^%s]+)')
    end
  end

  return nil
end

-- Execute interactive command using terminal interface
M.execute_interactive = function(cmd_args, options)
  local interactive_terminal = require('jj-nvim.ui.interactive_terminal')
  return interactive_terminal.run_interactive_command(cmd_args, options)
end

return M

