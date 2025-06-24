local M = {}

-- Available themes
M.themes = {
  'auto',       -- Try to detect from Neovim colorscheme
  'gruvbox',    -- Gruvbox color scheme
  'catppuccin', -- Catppuccin color scheme
  'nord',       -- Nord color scheme
  'tokyo-night', -- Tokyo Night color scheme
  'onedark',    -- One Dark color scheme
  'default',    -- Fallback generic colors
}

-- Get the appropriate theme module
M.get_theme = function(theme_name)
  if theme_name == 'auto' then
    return M.detect_theme()
  end
  
  local ok, theme = pcall(require, 'jj-nvim.themes.' .. theme_name)
  if ok then
    return theme
  end
  
  -- Fallback to default
  return require('jj-nvim.themes.default')
end

-- Try to detect theme from Neovim colorscheme
M.detect_theme = function()
  local colorscheme = vim.g.colors_name or 'default'
  
  -- Map common Neovim colorschemes to our themes
  local scheme_map = {
    ['gruvbox'] = 'gruvbox',
    ['gruvbox-dark'] = 'gruvbox',
    ['gruvbox-light'] = 'gruvbox',
    ['catppuccin'] = 'catppuccin',
    ['catppuccin-mocha'] = 'catppuccin',
    ['catppuccin-macchiato'] = 'catppuccin',
    ['catppuccin-frappe'] = 'catppuccin',
    ['catppuccin-latte'] = 'catppuccin',
    ['nord'] = 'nord',
    ['tokyonight'] = 'tokyo-night',
    ['tokyonight-night'] = 'tokyo-night',
    ['tokyonight-storm'] = 'tokyo-night',
    ['onedark'] = 'onedark',
    ['onedarkpro'] = 'onedark',
  }
  
  local detected = scheme_map[colorscheme] or 'default'
  return M.get_theme(detected)
end

-- Map jj color names to theme colors
M.map_jj_color = function(jj_color_name, theme)
  if not jj_color_name or not theme or not theme.colors then
    return nil
  end
  
  -- Remove quotes and normalize
  jj_color_name = jj_color_name:gsub('"', ''):lower()
  
  -- Map jj color names to theme color keys
  local color_map = {
    ['red'] = 'red',
    ['green'] = 'green', 
    ['yellow'] = 'yellow',
    ['blue'] = 'blue',
    ['magenta'] = 'magenta',
    ['cyan'] = 'cyan',
    ['white'] = 'white',
    ['black'] = 'black',
    ['bright red'] = 'bright_red',
    ['bright green'] = 'bright_green',
    ['bright yellow'] = 'bright_yellow', 
    ['bright blue'] = 'bright_blue',
    ['bright magenta'] = 'bright_magenta',
    ['bright cyan'] = 'bright_cyan',
    ['bright white'] = 'bright_white',
    ['bright black'] = 'bright_black',
    ['default'] = nil,
  }
  
  local color_key = color_map[jj_color_name]
  if color_key and theme.colors[color_key] then
    return theme.colors[color_key]
  end
  
  return nil
end

return M