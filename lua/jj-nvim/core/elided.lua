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
  
  -- Graph symbols that should be preserved with normal graph coloring (no spaces)
  local graph_chars = "[│├─┤╭╰╮╯@○◆×]"
  
  -- Look for the ~ symbol or (elided revisions) text
  local tilde_pos = clean_line:find("~")
  local elided_text_pos = clean_line:find("%(elided revisions%)")
  
  if tilde_pos then
    -- Split into: pre-graph, ~, post content
    local pre_tilde = clean_line:sub(1, tilde_pos - 1)
    local post_tilde = clean_line:sub(tilde_pos + 1)
    
    -- Add graph part before the ~
    if pre_tilde ~= "" then
      local graph_part = CommitPart.new("graph",
        pre_tilde,
        function(text, COLORS) return "" end,
        true)
      -- Set a dummy commit reference for graph symbol coloring
      graph_part._commit_ref = { is_current = function() return false end, root = false }
      table.insert(parts, graph_part)
    end
    
    -- Add the ~ symbol with elided coloring
    table.insert(parts, CommitPart.new("elided_content",
      "~",
      function(text, COLORS) 
        return COLORS.elided_revisions
      end,
      true))
    
    -- Parse what comes after the ~ more carefully
    local remaining = post_tilde
    local pos = 1
    
    while pos <= #remaining do
      local char = remaining:sub(pos, pos)
      
      if char:match(graph_chars) then
        -- Found a graph character, collect consecutive graph chars and spaces
        local graph_start = pos
        while pos <= #remaining do
          local c = remaining:sub(pos, pos)
          if c:match(graph_chars) or c == " " then
            pos = pos + 1
          else
            break
          end
        end
        
        local graph_text = remaining:sub(graph_start, pos - 1)
        if graph_text ~= "" then
          local graph_part = CommitPart.new("graph",
            graph_text,
            function(text, COLORS) return "" end,
            true)
          graph_part._commit_ref = { is_current = function() return false end, root = false }
          table.insert(parts, graph_part)
        end
      elseif char == "(" and remaining:sub(pos):match("^%(elided revisions%)") then
        -- Found elided revisions text
        local elided_part = CommitPart.new("elided_content",
          "(elided revisions)",
          function(text, COLORS) 
            return COLORS.elided_revisions
          end,
          true)
        table.insert(parts, elided_part)
        pos = pos + 18  -- Length of "(elided revisions)"
      else
        -- Other character, treat as elided content until we hit graph or elided text
        local content_start = pos
        while pos <= #remaining do
          local c = remaining:sub(pos, pos)
          if c:match(graph_chars) or remaining:sub(pos):match("^%(elided revisions%)") then
            break
          end
          pos = pos + 1
        end
        
        local content_text = remaining:sub(content_start, pos - 1)
        if content_text ~= "" then
          table.insert(parts, CommitPart.new("elided_content",
            content_text,
            function(text, COLORS) 
              return COLORS.elided_revisions
            end,
            true))
        end
      end
    end
    
  elseif elided_text_pos then
    -- Handle "(elided revisions)" text
    local pre_elided = clean_line:sub(1, elided_text_pos - 1)
    local elided_text = clean_line:sub(elided_text_pos)
    
    -- Add graph part before the elided text
    if pre_elided ~= "" then
      local graph_part = CommitPart.new("graph",
        pre_elided,
        function(text, COLORS) return "" end,
        true)
      -- Set a dummy commit reference for graph symbol coloring
      graph_part._commit_ref = { is_current = function() return false end, root = false }
      table.insert(parts, graph_part)
    end
    
    -- Add the elided text with elided coloring
    table.insert(parts, CommitPart.new("elided_content",
      elided_text,
      function(text, COLORS) 
        return COLORS.elided_revisions
      end,
      true))
  else
    -- Fallback: check if line contains only graph chars and spaces
    if clean_line:match("^[│├─┤╭╰╮╯@○◆×%s]*$") then
      local graph_part = CommitPart.new("graph",
        clean_line,
        function(text, COLORS) return "" end,
        true)
      -- Set a dummy commit reference for graph symbol coloring
      graph_part._commit_ref = { is_current = function() return false end, root = false }
      table.insert(parts, graph_part)
    else
      -- No graph chars, treat as elided content
      table.insert(parts, CommitPart.new("elided_content",
        clean_line,
        function(text, COLORS) 
          return COLORS.elided_revisions
        end,
        clean_line ~= ""))
    end
  end

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