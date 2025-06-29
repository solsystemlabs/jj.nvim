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
  
  local result = vim.system(cmd, { text = true }):wait()
  
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
  
  return M.execute(cmd_args, { silent = options.silent })
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
  
  return M.execute(cmd_args, { silent = options.silent })
end

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
  
  return M.execute(cmd_args, { silent = options.silent })
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
  
  return M.execute(cmd_args, { silent = options.silent })
end

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
  
  return M.execute(cmd_args, { silent = options.silent })
end

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
  
  return M.execute(cmd_args, { silent = options.silent })
end

-- Commit working copy changes
M.commit = function(message, options)
  options = options or {}
  local cmd_args = { 'commit' }
  
  -- Add message if provided
  if message and message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, message)
  end
  
  -- Add interactive mode
  if options.interactive then
    table.insert(cmd_args, '--interactive')
  end
  
  -- Add diff tool for interactive mode
  if options.tool then
    table.insert(cmd_args, '--tool')
    table.insert(cmd_args, options.tool)
  end
  
  -- Add author options
  if options.reset_author then
    table.insert(cmd_args, '--reset-author')
  end
  
  if options.author then
    table.insert(cmd_args, '--author')
    table.insert(cmd_args, options.author)
  end
  
  -- Add filesets/paths if specified
  if options.filesets and #options.filesets > 0 then
    for _, fileset in ipairs(options.filesets) do
      table.insert(cmd_args, fileset)
    end
  end
  
  return M.execute(cmd_args, { silent = options.silent })
end

-- Execute interactive command using terminal interface
M.execute_interactive = function(cmd_args, options)
  local interactive_terminal = require('jj-nvim.ui.interactive_terminal')
  return interactive_terminal.run_interactive_command(cmd_args, options)
end

-- Interactive commit
M.commit_interactive = function(options)
  options = options or {}
  local cmd_args = { 'commit', '--interactive' }
  
  -- Add diff tool if specified
  if options.tool then
    table.insert(cmd_args, '--tool')
    table.insert(cmd_args, options.tool)
  end
  
  -- Add author options
  if options.reset_author then
    table.insert(cmd_args, '--reset-author')
  end
  
  if options.author then
    table.insert(cmd_args, '--author')
    table.insert(cmd_args, options.author)
  end
  
  -- Add filesets/paths if specified
  if options.filesets and #options.filesets > 0 then
    for _, fileset in ipairs(options.filesets) do
      table.insert(cmd_args, fileset)
    end
  end
  
  return M.execute_interactive(cmd_args, options)
end

-- Interactive split
M.split_interactive = function(commit_id, options)
  options = options or {}
  local cmd_args = { 'split', '--interactive' }
  
  if commit_id and commit_id ~= "" then
    table.insert(cmd_args, '-r')
    table.insert(cmd_args, commit_id)
  end
  
  return M.execute_interactive(cmd_args, options)
end

-- Interactive squash
M.squash_interactive = function(commit_id, options)
  options = options or {}
  local cmd_args = { 'squash', '--interactive' }
  
  if commit_id and commit_id ~= "" then
    table.insert(cmd_args, '-r')
    table.insert(cmd_args, commit_id)
  end
  
  return M.execute_interactive(cmd_args, options)
end

return M