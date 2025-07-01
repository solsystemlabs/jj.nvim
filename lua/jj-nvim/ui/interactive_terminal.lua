local M = {}

local config = require('jj-nvim.config')

-- Interactive terminal state
local state = {
  win_id = nil,
  buf_id = nil,
  job_id = nil,
  callbacks = nil,
}

-- Create floating terminal window
local function create_terminal_window()
  local float_config = config.get('interactive.float') or {}
  local width_ratio = float_config.width or 0.9
  local height_ratio = float_config.height or 0.8
  local border = float_config.border or 'rounded'
  
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  
  local width = math.floor(screen_width * width_ratio)
  local height = math.floor(screen_height * height_ratio)
  local col = math.floor((screen_width - width) / 2)
  local row = math.floor((screen_height - height) / 2)
  
  -- Create buffer
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf_id, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf_id, 'filetype', 'jj-interactive')
  
  -- Window configuration
  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = border,
    zindex = 200,
  }
  
  -- Create floating window
  local win_id = vim.api.nvim_open_win(buf_id, true, win_config)
  
  -- Set window options
  vim.api.nvim_win_set_option(win_id, 'wrap', false)
  vim.api.nvim_win_set_option(win_id, 'number', false)
  vim.api.nvim_win_set_option(win_id, 'relativenumber', false)
  vim.api.nvim_win_set_option(win_id, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(win_id, 'cursorline', false)
  
  return win_id, buf_id
end

-- Clean up terminal state
local function cleanup()
  if state.job_id then
    vim.fn.jobstop(state.job_id)
    state.job_id = nil
  end
  
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, false)
  end
  
  state.win_id = nil
  state.buf_id = nil
  state.callbacks = nil
end

-- Handle terminal exit
local function on_exit(job_id, exit_code, event)
  -- Store callbacks before cleanup
  local callbacks = state.callbacks
  
  if exit_code == 0 then
    -- Success - auto close and run success callback
    cleanup()
    
    -- Schedule refresh to avoid potential deadlocks
    vim.schedule(function()
      require('jj-nvim').refresh()
    end)
    
    if callbacks and callbacks.on_success then
      -- Schedule callback to avoid blocking
      vim.schedule(function()
        callbacks.on_success()
      end)
    end
  else
    -- Error - show message but keep terminal open for user to see error
    local error_msg = string.format("Command failed with exit code %d. Press 'q' to close.", exit_code)
    vim.notify(error_msg, vim.log.levels.WARN)
    
    -- Set up keymap to close on 'q'
    if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
      vim.keymap.set('n', 'q', function()
        cleanup()
        -- Schedule refresh to avoid blocking main thread
        vim.schedule(function()
          require('jj-nvim').refresh()
        end)
      end, { buffer = state.buf_id, noremap = true, silent = true })
    end
    
    if callbacks and callbacks.on_error then
      -- Schedule callback to avoid blocking
      vim.schedule(function()
        callbacks.on_error(exit_code)
      end)
    end
  end
end

-- Run interactive command in terminal
M.run_interactive_command = function(cmd_args, options)
  options = options or {}
  
  -- Check if another interactive command is already running
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.notify("An interactive command is already running", vim.log.levels.WARN)
    return false
  end
  
  -- Validate command
  if not cmd_args or type(cmd_args) ~= 'table' or #cmd_args == 0 then
    vim.notify("Invalid command arguments", vim.log.levels.ERROR)
    return false
  end
  
  -- Build full command
  local full_cmd = { 'jj' }
  for _, arg in ipairs(cmd_args) do
    table.insert(full_cmd, arg)
  end
  
  -- Create terminal window
  local win_id, buf_id = create_terminal_window()
  
  -- Update state
  state.win_id = win_id
  state.buf_id = buf_id
  state.callbacks = {
    on_success = options.on_success,
    on_error = options.on_error,
    on_cancel = options.on_cancel,
  }
  
  
  -- Set up escape key to cancel
  vim.keymap.set('n', '<Esc>', function()
    cleanup()
    -- Schedule refresh to avoid blocking
    vim.schedule(function()
      require('jj-nvim').refresh()
    end)
    if state.callbacks and state.callbacks.on_cancel then
      vim.schedule(function()
        state.callbacks.on_cancel()
      end)
    end
  end, { buffer = buf_id, noremap = true, silent = true })
  
  -- Start terminal with command
  state.job_id = vim.fn.termopen(full_cmd, {
    on_exit = on_exit,
    cwd = options.cwd or vim.fn.getcwd(),
  })
  
  if state.job_id == 0 then
    cleanup()
    vim.notify("Failed to start interactive command", vim.log.levels.ERROR)
    return false
  end
  
  -- Enter insert mode to start interacting immediately
  vim.cmd('startinsert')
  
  return true
end

-- Check if interactive terminal is currently running
M.is_running = function()
  return state.win_id and vim.api.nvim_win_is_valid(state.win_id)
end

-- Force close interactive terminal
M.close = function()
  cleanup()
end

return M