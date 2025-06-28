local M = {}

-- Validate buffer ID
M.buffer = function(buf_id)
  return buf_id and vim.api.nvim_buf_is_valid(buf_id)
end

-- Validate window ID  
M.window = function(win_id)
  return win_id and vim.api.nvim_win_is_valid(win_id)
end

-- Validate both buffer and window
M.buffer_and_window = function(buf_id, win_id)
  return M.buffer(buf_id) and M.window(win_id)
end

-- Early return helper for invalid buffer
M.check_buffer_or_return = function(buf_id, return_value)
  if not M.buffer(buf_id) then
    return return_value or false
  end
end

-- Early return helper for invalid window
M.check_window_or_return = function(win_id, return_value)
  if not M.window(win_id) then
    return return_value or false
  end
end

return M