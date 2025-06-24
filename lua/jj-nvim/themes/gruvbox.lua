-- Gruvbox color theme for jj-nvim
-- Based on the popular Gruvbox color scheme

local base = require('jj-nvim.themes.base')

local colors = {
  -- Basic colors
  black = '#282828',
  red = '#cc241d',
  green = '#98971a',
  yellow = '#d79921',
  blue = '#458588',
  magenta = '#b16286',
  cyan = '#689d6a',
  white = '#a89984',

  -- Bright colors
  bright_black = '#928374',
  bright_red = '#fb4934',
  bright_green = '#b8bb26',
  bright_yellow = '#fabd2f',
  bright_blue = '#83a598',
  bright_magenta = '#d3869b',
  bright_cyan = '#8ec07c',
  bright_white = '#ebdbb2',

  -- Background colors
  bg = '#282828',
  bg1 = '#3c3836',
  bg2 = '#504945',
  bg3 = '#665c54',
  bg4 = '#7c6f64',

  -- Foreground colors
  fg = '#ebdbb2',
  fg1 = '#ebdbb2',
  fg2 = '#d5c4a1',
  fg3 = '#bdae93',
  fg4 = '#a89984',
}

return base.create_theme("Gruvbox", colors)

