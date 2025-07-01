-- Test utilities and helpers
local M = {}

-- Assert that a value is not nil
function M.assert_not_nil(value, message)
  if value == nil then
    error(message or "Expected value to not be nil")
  end
end

-- Assert that a value is nil
function M.assert_nil(value, message)
  if value ~= nil then
    error(message or "Expected value to be nil")
  end
end

-- Assert that two values are equal
function M.assert_equal(expected, actual, message)
  if expected ~= actual then
    error(string.format(
      "%s\nExpected: %s\nActual: %s",
      message or "Values are not equal",
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

-- Assert that a table contains a specific key
function M.assert_has_key(tbl, key, message)
  if type(tbl) ~= 'table' then
    error(message or "Expected table")
  end
  if tbl[key] == nil then
    error(string.format(
      "%s\nTable does not contain key: %s\nTable: %s",
      message or "Key not found",
      tostring(key),
      vim.inspect(tbl)
    ))
  end
end

-- Assert that a table has a specific length
function M.assert_length(tbl, expected_length, message)
  if type(tbl) ~= 'table' then
    error(message or "Expected table")
  end
  local actual_length = #tbl
  if actual_length ~= expected_length then
    error(string.format(
      "%s\nExpected length: %d\nActual length: %d",
      message or "Length mismatch",
      expected_length,
      actual_length
    ))
  end
end

-- Assert that a string contains a substring
function M.assert_contains(str, substring, message)
  if type(str) ~= 'string' then
    error(message or "Expected string")
  end
  if not string.find(str, substring, 1, true) then
    error(string.format(
      "%s\nString: %s\nDoes not contain: %s",
      message or "Substring not found",
      str,
      substring
    ))
  end
end

-- Assert that a string matches a pattern
function M.assert_matches(str, pattern, message)
  if type(str) ~= 'string' then
    error(message or "Expected string")
  end
  if not string.match(str, pattern) then
    error(string.format(
      "%s\nString: %s\nDoes not match pattern: %s",
      message or "Pattern not matched",
      str,
      pattern
    ))
  end
end

-- Create a temporary buffer for testing
function M.create_temp_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  return buf
end

-- Clean up a buffer
function M.cleanup_buffer(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

-- Create a temporary window for testing
function M.create_temp_window(buf)
  buf = buf or M.create_temp_buffer()
  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    width = 80,
    height = 24,
    row = 0,
    col = 0,
    style = 'minimal'
  })
  return win, buf
end

-- Clean up a window
function M.cleanup_window(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- Run a function in a protected environment and return success/error
function M.pcall_with_traceback(func, ...)
  local success, result = xpcall(func, debug.traceback, ...)
  return success, result
end

-- Wait for a condition to be true (useful for async tests)
function M.wait_for(condition, timeout, interval)
  timeout = timeout or 1000  -- 1 second default
  interval = interval or 10  -- 10ms default
  
  local start_time = vim.loop.now()
  
  while vim.loop.now() - start_time < timeout do
    if condition() then
      return true
    end
    vim.loop.sleep(interval)
  end
  
  return false
end

-- Deep copy a table
function M.deepcopy(tbl)
  if type(tbl) ~= 'table' then
    return tbl
  end
  
  local copy = {}
  for key, value in pairs(tbl) do
    copy[key] = M.deepcopy(value)
  end
  
  return copy
end

-- Check if we're running in a jj repository
function M.is_jj_repo()
  local result = vim.fn.system('jj status')
  return vim.v.shell_error == 0
end

-- Skip a test if not in a jj repository
function M.skip_if_not_jj_repo()
  if not M.is_jj_repo() then
    pending("Skipping test - not in a jj repository")
  end
end

return M