local M = {}

-- Theme definitions with border color palettes
M.themes = {
  -- Default theme with neutral colors
  default = {
    border = {
      gray = '#666666',
      subtle = '#444444',
      accent = '#888888',
      muted = '#333333',
    }
  },
  
  -- Gruvbox theme colors
  gruvbox = {
    border = {
      gray = '#665c54',    -- gruvbox gray
      subtle = '#3c3836',  -- gruvbox dark gray
      accent = '#928374',  -- gruvbox light gray
      muted = '#282828',   -- gruvbox dark background
    }
  },
  
  -- Catppuccin theme colors
  catppuccin = {
    border = {
      gray = '#6c7086',    -- catppuccin overlay2
      subtle = '#45475a',  -- catppuccin surface2
      accent = '#9399b2',  -- catppuccin overlay1
      muted = '#313244',   -- catppuccin surface0
    }
  },
  
  -- Tokyo Night theme colors
  tokyonight = {
    border = {
      gray = '#565f89',    -- tokyo night comment
      subtle = '#3b4261',  -- tokyo night bg_highlight
      accent = '#737aa2',  -- tokyo night dark5
      muted = '#24283b',   -- tokyo night bg_dark
    }
  },
  
  -- Nord theme colors
  nord = {
    border = {
      gray = '#616e88',    -- nord frost
      subtle = '#3b4252',  -- nord polar night
      accent = '#81a1c1',  -- nord frost blue
      muted = '#2e3440',   -- nord dark
    }
  }
}

-- Get theme-aware border color
M.get_border_color = function(color_name, theme_name)
  theme_name = theme_name or 'default'
  
  -- Get theme definition
  local theme = M.themes[theme_name] or M.themes.default
  
  -- Direct hex color support
  if color_name and color_name:match('^#%x%x%x%x%x%x$') then
    return color_name
  end
  
  -- Theme-aware color lookup
  if theme.border and theme.border[color_name] then
    return theme.border[color_name]
  end
  
  -- Fallback to default theme
  if M.themes.default.border[color_name] then
    return M.themes.default.border[color_name]
  end
  
  -- Ultimate fallback
  return '#666666'
end

-- Auto-detect theme from colorscheme (future enhancement)
M.detect_theme = function()
  local colorscheme = vim.g.colors_name or 'default'
  
  -- Simple theme detection based on colorscheme name
  if colorscheme:match('gruvbox') then
    return 'gruvbox'
  elseif colorscheme:match('catppuccin') then
    return 'catppuccin'
  elseif colorscheme:match('tokyonight') then
    return 'tokyonight'
  elseif colorscheme:match('nord') then
    return 'nord'
  else
    return 'default'
  end
end

-- Get all available themes
M.get_available_themes = function()
  local theme_names = {}
  for name, _ in pairs(M.themes) do
    table.insert(theme_names, name)
  end
  table.insert(theme_names, 'auto') -- Add auto-detection option
  return theme_names
end

-- Register a new theme (for future plugin extensions)
M.register_theme = function(name, theme_definition)
  M.themes[name] = theme_definition
end

return M