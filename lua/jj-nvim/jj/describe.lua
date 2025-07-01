local M = {}

local commands = require('jj-nvim.jj.commands')

-- Set description for a revision
M.describe = function(change_id, message, options)
  if not change_id or change_id == "" then
    return nil, "No change ID provided"
  end

  if not message then
    return nil, "No message provided"
  end

  options = options or {}
  local cmd_args = { 'describe', '-r', change_id, '-m', message }

  -- Add additional options if specified
  if options.reset_author then
    table.insert(cmd_args, '--reset-author')
  end

  if options.author then
    table.insert(cmd_args, '--author')
    table.insert(cmd_args, options.author)
  end

  return commands.execute(cmd_args, { silent = options.silent })
end

return M