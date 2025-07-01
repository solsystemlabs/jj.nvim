local M = {}

local commands = require('jj-nvim.jj.commands')

-- Get repository status
M.get_status = function(options)
  options = options or {}
  local cmd_args = { 'status' }

  -- Add file path restrictions if specified
  if options.paths and #options.paths > 0 then
    for _, path in ipairs(options.paths) do
      table.insert(cmd_args, path)
    end
  end

  -- Always request color output for better display
  if not options.no_color then
    table.insert(cmd_args, '--color=always')
  end

  return commands.execute(cmd_args, { silent = options.silent })
end

return M