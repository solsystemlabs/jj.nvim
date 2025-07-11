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

  -- Add --ignore-immutable flag if requested
  if opts.ignore_immutable then
    table.insert(cmd, '--ignore-immutable')
  end

  local result = vim.system(cmd, { text = true }):wait(30000) -- 30 second timeout

  -- Handle timeout case where result is nil
  if not result then
    local error_msg = 'jj command timed out after 30 seconds'
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

-- Async version of execute for long-running operations
M.execute_async = function(cmd, opts, callback)
  opts = opts or {}
  callback = callback or function() end
  
  if type(cmd) == 'string' then
    cmd = vim.split(cmd, ' ')
  end
  
  table.insert(cmd, 1, 'jj')
  
  -- Add --ignore-immutable flag if requested
  if opts.ignore_immutable then
    table.insert(cmd, '--ignore-immutable')
  end
  
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if not result then
        local error_msg = 'jj command failed to execute'
        if not opts.silent then
          vim.notify(error_msg, vim.log.levels.ERROR)
        end
        callback(nil, error_msg)
        return
      end
      
      if result.code ~= 0 then
        local error_msg = result.stderr or 'Unknown error'
        if not opts.silent then
          vim.notify('jj command failed: ' .. error_msg, vim.log.levels.ERROR)
        end
        callback(nil, error_msg)
        return
      end
      
      callback(result.stdout, nil)
    end)
  end)
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

M.get_git_remotes = function()
  local result, err = M.execute('git remote list', { silent = true })
  if not result then
    return {}
  end

  local remotes = {}
  for line in result:gmatch('[^\r\n]+') do
    local remote_name = line:match('^([^%s]+)')
    if remote_name then
      table.insert(remotes, remote_name)
    end
  end

  return remotes
end

-- Execute interactive command using terminal interface
M.execute_interactive = function(cmd_args, options)
  local interactive_terminal = require('jj-nvim.ui.interactive_terminal')
  return interactive_terminal.run_interactive_command(cmd_args, options)
end

-- Helper function to check if error is immutable-related
local function is_immutable_error(error_msg)
  return error_msg and error_msg:find("immutable") ~= nil
end

-- Execute command with automatic immutable error handling and user prompt
M.execute_with_immutable_prompt = function(args, opts)
  opts = opts or {}
  
  -- First attempt - execute normally
  local result, error_msg = M.execute(args, opts)
  
  -- If successful or not an immutable error, return as normal
  if result or not is_immutable_error(error_msg) then
    return result, error_msg
  end
  
  -- Check if user wants to skip prompting (for programmatic use)
  if opts.no_immutable_prompt then
    return result, error_msg
  end
  
  -- Immutable error detected - prompt user
  local choice = vim.fn.confirm(
    "This commit has been pushed to remote and is marked immutable.\n" ..
    "Do you want to override the immutable state?",
    "&Yes\n&No",
    2 -- Default to No
  )
  
  if choice == 1 then
    -- User chose Yes - retry with --ignore-immutable
    local retry_opts = vim.tbl_deep_extend("force", opts, { ignore_immutable = true })
    return M.execute(args, retry_opts)
  else
    -- User chose No - return original error
    return result, error_msg
  end
end

-- Execute interactive command with immutable error handling
M.execute_interactive_with_immutable_prompt = function(cmd_args, options)
  options = options or {}
  
  -- For interactive commands, we need to modify the command args directly
  -- since interactive terminal doesn't go through our execute function
  local function retry_with_immutable_override()
    local modified_args = vim.deepcopy(cmd_args)
    table.insert(modified_args, '--ignore-immutable')
    return M.execute_interactive(modified_args, options)
  end
  
  -- Set up error callback to handle immutable errors
  local original_on_error = options.on_error
  options.on_error = function(exit_code)
    -- For interactive commands, we can't easily detect immutable errors
    -- So we'll ask the user if they want to try with --ignore-immutable
    if exit_code ~= 0 then
      vim.schedule(function()
        local choice = vim.fn.confirm(
          "Command failed. This might be due to immutable commits.\n" ..
          "Do you want to retry ignoring immutable state?",
          "&Yes\n&No",
          2 -- Default to No
        )
        
        if choice == 1 then
          -- Retry with --ignore-immutable
          retry_with_immutable_override()
        else
          -- Call original error handler if it exists
          if original_on_error then
            original_on_error(exit_code)
          end
        end
      end)
    else
      -- Call original error handler for other errors
      if original_on_error then
        original_on_error(exit_code)
      end
    end
  end
  
  return M.execute_interactive(cmd_args, options)
end

return M

