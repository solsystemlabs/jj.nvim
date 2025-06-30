local M = {}

-- Constants for gutter space
local GUTTER_COLUMNS = {
  LEFT = 1,  -- Account for the left gutter column
  RIGHT = 1, -- Add right padding for visual balance
}

-- Get window width with fallback for invalid windows
M.get_width = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return 80 -- reasonable fallback width
  end
  return vim.api.nvim_win_get_width(win_id)
end

-- Get effective width for content rendering (accounting for gutter columns)
M.get_effective_width = function(win_id)
  local raw_width = M.get_width(win_id)
  return raw_width - GUTTER_COLUMNS.LEFT - GUTTER_COLUMNS.RIGHT
end

-- Get window width or fallback to config default
M.get_width_or_config = function(win_id, config_fallback)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return config_fallback or 80
  end
  return vim.api.nvim_win_get_width(win_id)
end

-- Get effective width or fallback to config default
M.get_effective_width_or_config = function(win_id, config_fallback)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    local fallback = config_fallback or 80
    return fallback - GUTTER_COLUMNS.LEFT - GUTTER_COLUMNS.RIGHT
  end
  return M.get_effective_width(win_id)
end

-- Validate window ID
M.is_valid = function(win_id)
  return win_id and vim.api.nvim_win_is_valid(win_id)
end

return M