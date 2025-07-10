local M = {}

-- Theme definitions with border color palettes and semantic colors
M.themes = {
  -- Default theme with neutral colors
  default = {
    border = {
      gray = '#666666',
      subtle = '#444444',
      accent = '#888888',
      muted = '#333333',
    },
    colors = {
      red = '#ff6b6b',
      green = '#51cf66',
      bright_green = '#69db7c',
      yellow = '#feca57',
      bright_yellow = '#fffa65',
      blue = '#74b9ff',
      bright_blue = '#a29bfe',
      magenta = '#fd79a8',
      bright_magenta = '#e84393',
      cyan = '#55efc4',
      bright_cyan = '#81ecec',
      bright_black = '#666666',
      white = '#ffffff',
    },
    selection = {
      background = '#4a4a4a',  -- Subtle gray background for selected commits
      border = '#666666',      -- Border color for selection indicators
    }
  },
  
  -- Gruvbox theme colors
  gruvbox = {
    border = {
      gray = '#665c54',    -- gruvbox gray
      subtle = '#3c3836',  -- gruvbox dark gray
      accent = '#928374',  -- gruvbox light gray
      muted = '#282828',   -- gruvbox dark background
    },
    colors = {
      red = '#fb4934',
      green = '#b8bb26',
      bright_green = '#b8bb26',
      yellow = '#fabd2f',
      bright_yellow = '#fabd2f',
      blue = '#83a598',
      bright_blue = '#83a598',
      magenta = '#d3869b',
      bright_magenta = '#d3869b',
      cyan = '#8ec07c',
      bright_cyan = '#8ec07c',
      bright_black = '#928374',
      white = '#ebdbb2',
    },
    selection = {
      background = '#504945',  -- gruvbox bg2 for selected commits
      border = '#665c54',      -- gruvbox gray for selection indicators
    }
  },
  
  -- Catppuccin theme colors
  catppuccin = {
    border = {
      gray = '#6c7086',    -- catppuccin overlay2
      subtle = '#45475a',  -- catppuccin surface2
      accent = '#9399b2',  -- catppuccin overlay1
      muted = '#313244',   -- catppuccin surface0
    },
    colors = {
      red = '#f38ba8',
      green = '#a6e3a1',
      bright_green = '#a6e3a1',
      yellow = '#f9e2af',
      bright_yellow = '#f9e2af',
      blue = '#89b4fa',
      bright_blue = '#89b4fa',
      magenta = '#cba6f7',
      bright_magenta = '#cba6f7',
      cyan = '#94e2d5',
      bright_cyan = '#94e2d5',
      bright_black = '#6c7086',
      white = '#cdd6f4',
    },
    selection = {
      background = '#45475a',  -- catppuccin surface2 for selected commits
      border = '#6c7086',      -- catppuccin overlay2 for selection indicators
    }
  },
  
  -- Tokyo Night theme colors
  tokyonight = {
    border = {
      gray = '#565f89',    -- tokyo night comment
      subtle = '#3b4261',  -- tokyo night bg_highlight
      accent = '#737aa2',  -- tokyo night dark5
      muted = '#24283b',   -- tokyo night bg_dark
    },
    colors = {
      red = '#f7768e',
      green = '#9ece6a',
      bright_green = '#9ece6a',
      yellow = '#e0af68',
      bright_yellow = '#e0af68',
      blue = '#7aa2f7',
      bright_blue = '#7aa2f7',
      magenta = '#bb9af7',
      bright_magenta = '#bb9af7',
      cyan = '#7dcfff',
      bright_cyan = '#7dcfff',
      bright_black = '#565f89',
      white = '#c0caf5',
    },
    selection = {
      background = '#3b4261',  -- tokyo night bg_highlight for selected commits
      border = '#565f89',      -- tokyo night comment for selection indicators
    }
  },
  
  -- Nord theme colors
  nord = {
    border = {
      gray = '#616e88',    -- nord frost
      subtle = '#3b4252',  -- nord polar night
      accent = '#81a1c1',  -- nord frost blue
      muted = '#2e3440',   -- nord dark
    },
    colors = {
      red = '#bf616a',
      green = '#a3be8c',
      bright_green = '#a3be8c',
      yellow = '#ebcb8b',
      bright_yellow = '#ebcb8b',
      blue = '#81a1c1',
      bright_blue = '#81a1c1',
      magenta = '#b48ead',
      bright_magenta = '#b48ead',
      cyan = '#88c0d0',
      bright_cyan = '#88c0d0',
      bright_black = '#4c566a',
      white = '#eceff4',
    },
    selection = {
      background = '#3b4252',  -- nord polar night for selected commits
      border = '#4c566a',      -- nord bright_black for selection indicators
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

-- Get theme-aware selection color
M.get_selection_color = function(color_name, theme_name)
  theme_name = theme_name or M.detect_theme()
  
  -- Get theme definition
  local theme = M.themes[theme_name] or M.themes.default
  
  -- Direct hex color support
  if color_name and color_name:match('^#%x%x%x%x%x%x$') then
    return color_name
  end
  
  -- Theme-aware color lookup
  if theme.selection and theme.selection[color_name] then
    return theme.selection[color_name]
  end
  
  -- Fallback to default theme
  if M.themes.default.selection and M.themes.default.selection[color_name] then
    return M.themes.default.selection[color_name]
  end
  
  -- Ultimate fallback
  if color_name == 'background' then
    return '#4a4a4a'
  elseif color_name == 'border' then
    return '#666666'
  end
  
  return '#4a4a4a'
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

-- Get theme definition by name
M.get_theme = function(theme_name)
  -- Handle auto detection
  if theme_name == 'auto' then
    theme_name = M.detect_theme()
  end
  
  -- Return theme or fallback to default
  return M.themes[theme_name] or M.themes.default
end

-- Map JJ color to theme color (placeholder function)
M.map_jj_color = function(jj_color, theme)
  -- For now, just return the original color or nil
  -- This function can be enhanced later for more sophisticated color mapping
  return jj_color
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