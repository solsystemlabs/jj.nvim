-- Base theme utilities for jj-nvim themes
local M = {}

-- Common 256-color element mappings for all themes
-- This maps 256-color numbers to their semantic meaning in jj log output
M.create_256_map = function(colors)
  return {
    [2] = colors.green,                            -- @ symbol (working copy) - muted green
    [3] = colors.yellow,                           -- author email
    [4] = colors.blue,                             -- standard commit IDs
    [5] = colors.magenta,                          -- bookmarks/other elements
    [6] = colors.cyan,                             -- alternative timestamp color
    [8] = colors.bright_black,                     -- dim/gray text
    [10] = colors.green,                           -- (empty) text - match @ symbol
    [12] = colors.bright_blue,                     -- latest commit ID (lighter blue)
    [13] = colors.bright_magenta,                  -- change IDs
    [14] = colors.bright_cyan,                     -- primary timestamp color
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