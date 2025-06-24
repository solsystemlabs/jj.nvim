local M = {}

local config = require('jj-nvim.config')
local window = require('jj-nvim.ui.window')
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