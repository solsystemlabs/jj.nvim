local M = {}

local commands = require('jj-nvim.jj.commands')

-- Get diff for a specific change/commit
M.get_diff = function(change_id, options)
  if not change_id or change_id == "" then
    return nil, "No change ID provided"
  end

  options = options or {}
  local cmd_args = { 'diff', '-r', change_id }

  -- Add format options
  if options.git then
    table.insert(cmd_args, '--git')
  end

  if options.stat then
    table.insert(cmd_args, '--stat')
  end

  if options.color_words then
    table.insert(cmd_args, '--color-words')
  end

  if options.name_only then
    table.insert(cmd_args, '--name-only')
  end

  -- Always request color output for better display
  if not options.no_color then
    table.insert(cmd_args, '--color=always')
  end

  return commands.execute(cmd_args, { silent = options.silent })
end

-- Get diff summary (--stat) for a specific change
M.get_diff_summary = function(change_id, options)
  options = options or {}
  options.stat = true
  return M.get_diff(change_id, options)
end

-- Get diff between two revisions
M.get_diff_range = function(from_rev, to_rev, options)
  if not from_rev or from_rev == "" or not to_rev or to_rev == "" then
    return nil, "Both from_rev and to_rev must be provided"
  end

  options = options or {}
  local cmd_args = { 'diff', '-r', from_rev .. '..' .. to_rev }

  -- Add format options (same as get_diff)
  if options.git then
    table.insert(cmd_args, '--git')
  end

  if options.stat then
    table.insert(cmd_args, '--stat')
  end

  if options.color_words then
    table.insert(cmd_args, '--color-words')
  end

  if options.name_only then
    table.insert(cmd_args, '--name-only')
  end

  if not options.no_color then
    table.insert(cmd_args, '--color=always')
  end

  return commands.execute(cmd_args, { silent = options.silent })
end

return M