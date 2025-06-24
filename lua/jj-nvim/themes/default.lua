-- Default color theme for jj-nvim
-- Generic colors that should work well in most terminals

local base = require('jj-nvim.themes.base')

local colors = {
  -- Basic colors - modern, pleasant defaults
  black = '#000000',
  red = '#dc2626',
  green = '#16a34a', 
  yellow = '#ca8a04',
  blue = '#2563eb',
  magenta = '#c026d3',
  cyan = '#0891b2',
  white = '#ffffff',
  
  -- Bright colors  
  bright_black = '#6b7280',
  bright_red = '#ef4444',
  bright_green = '#22c55e',
  bright_yellow = '#eab308',
  bright_blue = '#3b82f6',
  bright_magenta = '#d946ef',
  bright_cyan = '#06b6d4',
  bright_white = '#f9fafb',
}

return base.create_theme("Default", colors)