-- Mock the requires
local function mock_module() return {
  execute = function() return "", nil end,
  get = function() return "default" end,
  get_id = function() return "test123" end,
  get_display_id = function() return "test123" end,
  setup_highlights = function() end,
  parse_ansi_line = function() return {} end,
  strip_ansi = function(line) return line end,
} end

package.loaded['jj-nvim.jj.commands'] = mock_module()
package.loaded['jj-nvim.ui.buffer'] = mock_module()
package.loaded['jj-nvim.config'] = mock_module()
package.loaded['jj-nvim.core.commit'] = mock_module()
package.loaded['jj-nvim.utils.ansi'] = mock_module()

-- Mock vim API
vim = {
  api = {
    nvim_create_buf = function() return 1 end,
    nvim_buf_set_name = function() end,
    nvim_buf_set_option = function() end,
    nvim_buf_set_lines = function() end,
    nvim_buf_add_highlight = function() end,
    nvim_get_current_win = function() return 1 end,
    nvim_win_set_buf = function() end,
    nvim_win_close = function() end,
  },
  split = function(str, sep) 
    local result = {}
    for match in (str..sep):gmatch("(.-)"..sep) do
      table.insert(result, match)
    end
    return result
  end,
  keymap = { set = function() end },
  cmd = function() end,
  notify = function() end,
  log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
}

-- Check syntax
dofile('/Users/tayloreernisse/projects/jj-nvim/lua/jj-nvim/jj/actions.lua')
print('actions.lua syntax is valid')