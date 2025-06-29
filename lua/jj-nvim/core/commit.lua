local M = {}

-- Commit object representing a complete jj commit with all metadata
local Commit = {}
Commit.__index = Commit

-- Create a new Commit object from template data
function Commit.new(data)
  local self = setmetatable({}, Commit)

  -- Core identification
  self.change_id = data.change_id or ""
  self.commit_id = data.commit_id or ""
  self.short_change_id = data.short_change_id or ""
  self.short_commit_id = data.short_commit_id or ""
  self.shortest_change_id = data.shortest_change_id or ""
  self.shortest_commit_id = data.shortest_commit_id or ""

  -- Authorship information
  self.author = data.author or {}
  self.committer = data.committer or {}

  -- Content
  self.description = data.description or ""
  self.full_description = data.full_description or ""
  self.empty = data.empty or false

  -- Status flags
  self.current_working_copy = data.current_working_copy or false
  self.mine = data.mine or false
  self.root = data.root or false
  self.divergent = data.divergent or false
  self.immutable = data.immutable or false
  self.conflict = data.conflict or false
  self.hidden = data.hidden or false

  -- References
  self.bookmarks = data.bookmarks or {}
  self.local_bookmarks = data.local_bookmarks or {}
  self.remote_bookmarks = data.remote_bookmarks or {}
  self.tags = data.tags or {}
  self.git_refs = data.git_refs or {}
  self.git_head = data.git_head or false

  -- Relationships
  self.parents = data.parents or {}
  self.children = data.children or {}

  -- Display metadata (calculated during rendering)
  self.line_start = nil  -- First line in display buffer
  self.line_end = nil    -- Last line in display buffer
  self.header_line = nil -- Main commit line for navigation
  self.lines = {}        -- Display lines for this commit

  -- Graph structure (from parsing jj log output)
  self.graph_prefix = data.graph_prefix or "" -- Graph structure before commit symbol
  self.symbol = data.symbol or "○" -- Commit symbol (@, ○, ◆, ×)
  self.graph_suffix = data.graph_suffix or "" -- Graph structure after commit symbol
  self.complete_graph = data.complete_graph or "" -- Complete graph structure from jj log
  self.description_graph = data.description_graph or "" -- Graph structure for description line
  self.additional_lines = data.additional_lines or {} -- Description/connector lines with graph info


  return self
end

-- Get the display symbol for this commit (@ for current, ○ for others, ◆ for root)
function Commit:get_symbol()
  -- If we have a parsed symbol from jj log output, use that
  if self.symbol and self.symbol ~= "" then
    return self.symbol
  end

  -- Fallback to computed symbol
  if self.root then
    return "◆"
  elseif self.current_working_copy then
    return "@"
  else
    return "○"
  end
end

-- Get formatted author information
function Commit:get_author_display()
  -- Root commit gets special treatment
  if self.root then
    return "root()"
  end

  if self.author and self.author.email then
    return self.author.email
  elseif self.author and self.author.name then
    return self.author.name
  else
    return ""
  end
end

-- Get formatted timestamp (simplified format)
function Commit:get_timestamp_display()
  -- Root commits don't show timestamps
  if self.root then
    return ""
  end

  if not self.author or not self.author.timestamp then
    return ""
  end

  local timestamp = self.author.timestamp
  -- Parse ISO timestamp: "2025-06-24 23:59:35.000 -04:00"
  local year, month, day, hour, min, sec = timestamp:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")

  if year and month and day and hour and min and sec then
    -- Format as: YYYY-MM-DD HH:MM:SS (local time, no timezone)
    return string.format("%s-%s-%s %s:%s:%s", year, month, day, hour, min, sec)
  else
    -- Fallback to original timestamp if parsing fails
    return timestamp
  end
end

-- Check if this commit has a real description vs placeholder
function Commit:has_real_description()
  return self.description and self.description ~= "" and self.description ~= "(no description set)"
end

-- Get short description (first line only)
function Commit:get_short_description()
  local desc_text = ""

  -- Add "(empty)" indicator for empty commits
  if self.empty then
    desc_text = "(empty) "
  end

  -- Add the actual description
  if not self.description or self.description == "" then
    desc_text = desc_text .. "(no description set)"
  else
    local first_line = self.description:match("([^\n]*)")
    desc_text = desc_text .. (first_line or self.description)
  end

  return desc_text
end

-- Get description without empty prefix (for wrapping)
function Commit:get_description_text_only()
  if not self.description or self.description == "" then
    return "(no description set)"
  else
    local first_line = self.description:match("([^\n]*)")
    return first_line or self.description
  end
end

-- Check if this commit has an expandable description (multi-line)
function Commit:has_expandable_description()
  if not self.full_description or self.full_description == "" then
    return false
  end
  
  -- Check if full description has multiple lines
  local lines = vim.split(self.full_description, '\n', {plain = true})
  if #lines > 1 then
    -- Filter out empty lines to see if there's actually additional content
    local non_empty_lines = 0
    for _, line in ipairs(lines) do
      if line:match("%S") then -- Line contains non-whitespace
        non_empty_lines = non_empty_lines + 1
      end
    end
    return non_empty_lines > 1
  end
  
  -- Single line: check if full description is meaningfully different from first line
  -- (accounting for potential formatting differences)
  local first_line = lines[1] or ""
  local short_desc = self.description or ""
  
  -- Remove leading/trailing whitespace for comparison
  first_line = first_line:match("^%s*(.-)%s*$")
  short_desc = short_desc:match("^%s*(.-)%s*$")
  
  return first_line ~= short_desc and first_line ~= ""
end

-- Get full description lines (for expansion)
function Commit:get_full_description_lines()
  if not self.full_description or self.full_description == "" then
    -- Fallback to short description if no full description available
    return {self:get_short_description()}
  else
    -- Split full description into lines
    local lines = vim.split(self.full_description, '\n', {plain = true})
    
    -- Add "(empty)" prefix to first line if needed
    if self.empty and lines[1] and not lines[1]:find("^%(empty%) ") then
      lines[1] = "(empty) " .. lines[1]
    end
    
    return lines
  end
end

-- Get full description lines without empty prefix (for wrapping)
function Commit:get_description_lines_only()
  if not self.full_description or self.full_description == "" then
    -- Fallback to description text only
    return {self:get_description_text_only()}
  else
    -- Split full description into lines without empty prefix
    local lines = vim.split(self.full_description, '\n', {plain = true})
    
    -- If lines are empty, fallback to "(no description set)"
    if #lines == 0 or (lines[1] and lines[1]:match("^%s*$")) then
      return {"(no description set)"}
    end
    
    return lines
  end
end

-- Get bookmarks display string
function Commit:get_bookmarks_display()
  if #self.bookmarks == 0 then
    return ""
  end
  return table.concat(self.bookmarks, " ")
end

-- Check if this commit should be highlighted as current
function Commit:is_current()
  return self.current_working_copy
end

-- Get color function for author field
function Commit:get_author_color()
  return function(text, COLORS)
    if self.root then
      return COLORS.author_root
    else
      return self:is_current() and COLORS.author_current or COLORS.author_regular
    end
  end
end

-- Get color function for timestamp field
function Commit:get_timestamp_color()
  return function(text, COLORS)
    return self:is_current() and COLORS.timestamp_current or COLORS.timestamp_regular
  end
end

-- Get color function for change ID field
function Commit:get_change_id_color()
  return function(text, COLORS)
    return self:is_current() and COLORS.change_id_current or COLORS.change_id_regular
  end
end

-- Get color function for commit ID field
function Commit:get_commit_id_color()
  return function(text, COLORS)
    return self:is_current() and COLORS.commit_id_current or COLORS.commit_id_regular
  end
end

-- Generate structured parts for the main commit line
function Commit:get_main_line_parts()
  local CommitPart = require('jj-nvim.core.commit_part')
  local parts = {}
  
  -- Graph (always first)
  local graph_part = CommitPart.new("graph", 
    self.complete_graph or "", 
    function(text, COLORS) return "" end,  -- Color function not used for graph
    true)
  graph_part._commit_ref = self  -- Store commit reference for symbol coloring
  table.insert(parts, graph_part)
  
  -- Change ID
  local change_id = self.short_change_id or (self.change_id and self.change_id:sub(1, 8)) or ""
  table.insert(parts, CommitPart.new("change_id",
    change_id,
    self:get_change_id_color(),
    change_id ~= ""))
  
  -- Author
  local author = self:get_author_display()
  table.insert(parts, CommitPart.new("author",
    " " .. author,
    self:get_author_color(),
    author ~= ""))
  
  -- Timestamp
  local timestamp = self:get_timestamp_display()
  table.insert(parts, CommitPart.new("timestamp",
    " " .. timestamp,
    self:get_timestamp_color(),
    timestamp ~= ""))
  
  -- Bookmarks
  local bookmarks_str = self:get_bookmarks_display()
  table.insert(parts, CommitPart.new("bookmarks",
    " " .. bookmarks_str,
    function(text, COLORS) return COLORS.bookmarks end,
    bookmarks_str ~= ""))
  
  -- Commit ID
  local commit_id = self.short_commit_id or ""
  table.insert(parts, CommitPart.new("commit_id",
    " " .. commit_id,
    self:get_commit_id_color(),
    commit_id ~= ""))
  
  -- Conflict indicator
  table.insert(parts, CommitPart.new("conflict",
    " conflict",
    function(text, COLORS) return COLORS.conflict_indicator end,
    self.conflict))
  
  return parts
end

-- Generate structured parts for description line prefixes
function Commit:get_description_prefix_parts()
  local CommitPart = require('jj-nvim.core.commit_part')
  local parts = {}
  
  -- Empty indicator (only for empty commits)
  table.insert(parts, CommitPart.new("empty_indicator",
    "(empty) ",
    function(text, COLORS) return COLORS.empty_indicator end,
    self.empty))
  
  return parts
end


-- Factory function to create commits from template data
M.from_template_data = function(template_data)
  return Commit.new(template_data)
end

-- Utility functions for ID extraction (reduces duplication across modules)
M.get_id = function(commit)
  if not commit then
    return nil
  end
  return commit.change_id or commit.short_change_id
end

M.get_short_id = function(commit)
  if not commit then
    return nil
  end
  return commit.short_change_id or (commit.change_id and commit.change_id:sub(1, 8))
end

M.get_display_id = function(commit)
  if not commit then
    return "unknown"
  end
  return commit.short_change_id or commit.shortest_change_id or 
         (commit.change_id and commit.change_id:sub(1, 8)) or "unknown"
end

return M

