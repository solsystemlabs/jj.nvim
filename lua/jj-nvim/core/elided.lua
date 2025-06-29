local M = {}

-- Elided object representing an elided revisions section
local Elided = {}
Elided.__index = Elided

-- Create a new Elided object
function Elided.new(data)
  local self = setmetatable({}, Elided)

  -- Core identification
  self.type = "elided"
  self.lines = data.lines or {}

  -- Display metadata (calculated during rendering)
  self.line_start = nil  -- First line in display buffer
  self.line_end = nil    -- Last line in display buffer
  self.rendered_lines = {}  -- Display lines for this elided section

  return self
end

-- Generate structured parts for elided section lines
function Elided:get_line_parts(line_index)
  local CommitPart = require('jj-nvim.core.commit_part')
  local parts = {}
  
  local line = self.lines[line_index]
  if not line then
    return parts
  end

  -- Parse the line into graph structure and elided content
  local clean_line = require('jj-nvim.utils.ansi').strip_ansi(line)
  
  -- Find where the elided content starts (after graph structure)
  local graph_part = ""
  local content_part = ""
  
  -- Look for the ~ symbol or (elided revisions) text
  local tilde_pos = clean_line:find("~")
  local elided_text_pos = clean_line:find("%(elided revisions%)")
  
  if tilde_pos then
    graph_part = clean_line:sub(1, tilde_pos - 1)
    content_part = clean_line:sub(tilde_pos)
  elseif elided_text_pos then
    graph_part = clean_line:sub(1, elided_text_pos - 1) 
    content_part = clean_line:sub(elided_text_pos)
  else
    -- Fallback: treat entire line as content
    graph_part = ""
    content_part = clean_line
  end

  -- Graph part (if any)
  if graph_part ~= "" then
    table.insert(parts, CommitPart.new("graph",
      graph_part,
      function(text, COLORS) return "" end, -- No special coloring for elided graph
      true))
  end

  -- Elided content part
  table.insert(parts, CommitPart.new("elided_content",
    content_part,
    function(text, COLORS) 
      -- Return just the color prefix - the CommitPart will handle applying it
      return COLORS.elided_revisions
    end,
    content_part ~= ""))

  return parts
end

-- Get all line parts for all lines in this elided section
function Elided:get_all_line_parts()
  local all_parts = {}
  for i = 1, #self.lines do
    local line_parts = self:get_line_parts(i)
    table.insert(all_parts, line_parts)
  end
  return all_parts
end

-- Factory function to create elided sections
M.new = function(data)
  return Elided.new(data)
end

return M