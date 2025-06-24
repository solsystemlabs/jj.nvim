local M = {}

local commands = require('jj-nvim.jj.commands')
local config = require('jj-nvim.config')
local themes = require('jj-nvim.themes')


-- Cache for jj color configuration
local jj_colors_cache = nil

M.get_jj_colors = function()
  if jj_colors_cache then
    return jj_colors_cache
  end
  
  local result, err = commands.execute({'config', 'list', '--include-defaults'}, {silent = true})
  if not result then
    return {}
  end
  
  local colors = {}
  for line in result:gmatch('[^\r\n]+') do
    local key, value = line:match('^colors%.([^=]+)%s*=%s*"?([^"]*)"?')
    if key and value then
      colors[key] = value
    end
  end
  
  jj_colors_cache = colors
  return colors
end


-- Map 256-color numbers to jj semantic colors when possible
M.map_256_to_jj_color = function(color_num)
  -- Get current theme
  local theme_name = config.get('colors.theme') or 'auto'
  local theme = themes.get_theme(theme_name)
  
  -- Use theme-specific 256-color mappings if available
  if theme and theme.color_256_map and theme.color_256_map[color_num] then
    return theme.color_256_map[color_num]
  end
  
  -- Fallback to semantic mappings
  local jj_colors = M.get_jj_colors()
  local semantic_mappings = {
    [2] = themes.map_jj_color(jj_colors and jj_colors['working_copy'], theme) or (theme and theme.colors and theme.colors.bright_green),
    [13] = themes.map_jj_color(jj_colors and jj_colors['change_id'], theme) or (theme and theme.colors and theme.colors.bright_magenta),
    [8] = theme and theme.colors and theme.colors.bright_black,
    [3] = themes.map_jj_color(jj_colors and jj_colors['author'], theme) or (theme and theme.colors and theme.colors.yellow),
    [14] = themes.map_jj_color(jj_colors and jj_colors['timestamp'], theme) or (theme and theme.colors and theme.colors.bright_cyan),
    [4] = themes.map_jj_color(jj_colors and jj_colors['commit_id'], theme) or (theme and theme.colors and theme.colors.blue),
    [5] = themes.map_jj_color(jj_colors and jj_colors['bookmark'], theme) or (theme and theme.colors and theme.colors.magenta),
  }
  
  return semantic_mappings[color_num]
end

return M