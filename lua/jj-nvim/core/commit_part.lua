local M = {}

-- CommitPart represents a semantic piece of a commit line with styling information
local CommitPart = {}
CommitPart.__index = CommitPart

-- Create a new CommitPart
-- @param type string: semantic type like "graph", "change_id", "author", etc.
-- @param text string: plain text content
-- @param color_fn function: function that returns color codes for this text
-- @param visible boolean: whether this part should be displayed
function CommitPart.new(type, text, color_fn, visible)
  if visible == nil then visible = true end
  
  return setmetatable({
    type = type,
    text = text or "",
    color_fn = color_fn,
    visible = visible,
    _cached_width = nil,  -- Cached display width
  }, CommitPart)
end

-- Get the styled text with color codes applied
function CommitPart:get_styled_text()
  if not self.visible or self.text == "" then
    return ""
  end
  
  if self.color_fn then
    local renderer = require('jj-nvim.core.renderer')
    local COLORS = renderer.get_colors()
    local reset = COLORS.reset_fg or "\27[39m"
    local color_result = self.color_fn(self.text, COLORS)
    
    -- Special handling for graph parts that need symbol coloring
    if self.type == "graph" then
      return renderer.apply_symbol_colors(self.text, self._commit_ref)
    -- Special handling for change_id and commit_id that may return pre-formatted text
    elseif (self.type == "change_id" or self.type == "commit_id") and color_result:find(COLORS.reset, 1, true) then
      -- Color function returned pre-formatted text with internal coloring, just add final reset
      return color_result .. reset
    else
      -- Standard coloring: prefix + text + reset
      return color_result .. self.text .. reset
    end
  else
    return self.text
  end
end

-- Get the display width of this part's text (without color codes)
function CommitPart:get_width()
  if not self.visible or self.text == "" then
    return 0
  end
  
  if not self._cached_width then
    self._cached_width = vim.fn.strdisplaywidth(self.text)
  end
  
  return self._cached_width
end

-- Check if this part has any content to display
function CommitPart:has_content()
  return self.visible and self.text ~= ""
end

-- Update the text content and invalidate width cache
function CommitPart:set_text(text)
  self.text = text or ""
  self._cached_width = nil
end

-- Set visibility and invalidate width cache if needed
function CommitPart:set_visible(visible)
  self.visible = visible
  if not visible then
    self._cached_width = nil
  end
end

-- Factory function for creating parts
M.new = CommitPart.new

return M