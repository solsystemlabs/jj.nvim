local M = {}

local config = require('jj-nvim.config')
local window = require('jj-nvim.ui.window')
local buffer = require('jj-nvim.ui.buffer')
local parser = require('jj-nvim.core.parser')
local jj_log = require('jj-nvim.jj.log')

M.setup = function(opts)
  config.setup(opts or {})
end

M.toggle = function()
  if window.is_open() then
    M.close()
  else
    M.show_log()
  end
end

M.show_log = function()
  -- Use new commit-based system
  local commits, err = parser.parse_all_commits()
  if err then
    vim.notify("Failed to parse commits: " .. err, vim.log.levels.ERROR)
    return
  end

  if not commits or #commits == 0 then
    vim.notify("No commits found. Is this a jj repository?", vim.log.levels.ERROR)
    return
  end

  -- Create buffer with commit objects
  local buf_id = buffer.create_from_commits(commits)
  if buf_id then
    window.open_with_buffer(buf_id)
  else
    vim.notify("Failed to create jj log buffer", vim.log.levels.ERROR)
  end
end

-- Legacy method for backward compatibility
M.show_log_legacy = function()
  local log_content = jj_log.get_log()
  if log_content then
    window.open(log_content)
  else
    vim.notify("Failed to get jj log. Is this a jj repository?", vim.log.levels.ERROR)
  end
end

M.close = function()
  window.close()
end

return M

