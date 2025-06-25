local M = {}

local config = require('jj-nvim.config')
local window = require('jj-nvim.ui.window')
local buffer = require('jj-nvim.ui.buffer')
local parser = require('jj-nvim.core.parser')
local jj_log = require('jj-nvim.jj.log')
local error_handler = require('jj-nvim.utils.error_handler')

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
  -- Use separate graph + data parsing system
  local commits, err = parser.parse_all_commits_with_separate_graph()
  if error_handler.handle_jj_error(err, "parse commits") then return end
  if error_handler.handle_empty_result(commits, "No commits found. Is this a jj repository?") then return end

  -- Create buffer with commit objects (including graph structure)
  local buf_id = buffer.create_from_commits(commits)
  if error_handler.handle_empty_result(buf_id, "Failed to create jj log buffer") then return end
  
  window.open_with_buffer(buf_id)
end

-- Legacy method for backward compatibility
M.show_log_legacy = function()
  local log_content = jj_log.get_log()
  if error_handler.handle_empty_result(log_content, "Failed to get jj log. Is this a jj repository?") then return end
  
  window.open(log_content)
end

M.close = function()
  window.close()
end

return M

