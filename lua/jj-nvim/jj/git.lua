local M = {}

local commands = require('jj-nvim.jj.commands')

-- JJ git fetch operation
M.git_fetch = function(options)
  options = options or {}
  local cmd_args = { 'git', 'fetch' }

  -- Add remote if specified
  if options.remote then
    table.insert(cmd_args, options.remote)
  end

  -- Add branch if specified
  if options.branch then
    table.insert(cmd_args, options.branch)
  end

  return commands.execute(cmd_args, { silent = options.silent })
end

-- JJ git push operation
M.git_push = function(options)
  options = options or {}
  local cmd_args = { 'git', 'push' }

  -- Add remote if specified
  if options.remote then
    table.insert(cmd_args, options.remote)
  end

  -- Add branch if specified
  if options.branch then
    table.insert(cmd_args, options.branch)
  end

  -- Add force flag if specified
  if options.force then
    table.insert(cmd_args, '--force-with-lease')
  end

  return commands.execute(cmd_args, { silent = options.silent })
end

return M