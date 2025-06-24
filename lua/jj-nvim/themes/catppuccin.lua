-- Catppuccin color theme for jj-nvim
-- Based on the popular Catppuccin color scheme (Mocha variant)

local base = require('jj-nvim.themes.base')

local colors = {
  -- Basic colors
  black = '#181825',
  red = '#f38ba8',
  green = '#a6e3a1',
  yellow = '#f9e2af',
  blue = '#89b4fa',
  magenta = '#f5c2e7',
  cyan = '#94e2d5',
  white = '#cdd6f4',
  
  -- Bright colors  
  bright_black = '#585b70',
  bright_red = '#f38ba8',
  bright_green = '#a6e3a1',
  bright_yellow = '#f9e2af',
  bright_blue = '#89b4fa',
  bright_magenta = '#f5c2e7',
  bright_cyan = '#94e2d5',
  bright_white = '#cdd6f4',
  
  -- Background colors
  bg = '#1e1e2e',
  bg1 = '#313244',
  bg2 = '#45475a',
  bg3 = '#585b70',
  bg4 = '#6c7086',
  
  -- Foreground colors
  fg = '#cdd6f4',
  fg1 = '#cdd6f4',
  fg2 = '#bac2de',
  fg3 = '#a6adc8',
  fg4 = '#9399b2',
}

return base.create_theme("Catppuccin", colors)