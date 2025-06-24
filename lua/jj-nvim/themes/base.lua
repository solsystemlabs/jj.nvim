-- Base theme utilities for jj-nvim themes
local M = {}

-- Common 256-color element mappings for all themes
-- This maps 256-color numbers to their semantic meaning in jj log output
M.create_256_map = function(colors)
  return {
    [2] = colors.bright_green or colors.green,     -- @ symbol (working copy)
    [13] = colors.bright_magenta or colors.magenta, -- change IDs
    [8] = colors.bright_black,                     -- dim/gray text
    [3] = colors.yellow,                           -- author
    [14] = colors.bright_cyan or colors.cyan,     -- timestamp
    [4] = colors.blue,                             -- commit IDs
    [5] = colors.magenta,                          -- bookmarks
  }
end

-- Create a theme with common structure
M.create_theme = function(name, colors)
  return {
    name = name,
    colors = colors,
    color_256_map = M.create_256_map(colors)
  }
end

return M