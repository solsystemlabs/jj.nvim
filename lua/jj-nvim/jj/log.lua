local M = {}

local commands = require('jj-nvim.jj.commands')
local config = require('jj-nvim.config')

M.get_log = function(opts)
  opts = opts or {}

  if not commands.is_jj_repo() then
    return nil
  end

  local format = opts.format or config.get('log.format') or 'short'
  local limit = opts.limit or config.get('log.limit') or 100

  local args = {
    'log',
    '--color=always',
    '--limit', tostring(limit),
  }

  if format == 'short' then
    -- Use default jj log format, no custom template
  elseif format == 'detailed' then
    table.insert(args, '--template')
    table.insert(args,
      'commit_id.short() ++ " " ++ author.name() ++ " " ++ committer.timestamp().ago() ++ "\\n" ++ description.first_line() ++ if(conflict, " (conflict)") ++ "\\n"')
  end

  local result, err = commands.execute(args)
  if not result then
    return nil
  end

  return result
end

M.parse_commit_id = function(line)
  if not line then return nil end

  local commit_id = line:match('^([a-f0-9]+)')
  return commit_id
end

M.get_commit_diff = function(commit_id)
  if not commit_id then return nil end

  local result, err = commands.execute({ 'show', commit_id })
  return result
end

M.get_commit_info = function(commit_id)
  if not commit_id then return nil end

  local args = {
    'log',
    '--limit', '1',
    '--revisions', commit_id,
    '--template',
    'commit_id ++ "\\n" ++ description ++ "\\n" ++ author.name() ++ " <" ++ author.email() ++ ">\\n" ++ committer.timestamp()'
  }

  local result, err = commands.execute(args)
  return result
end

return M

