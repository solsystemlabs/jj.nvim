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

  -- Color information (extracted from jj's ANSI output)
  self.colors = data.colors or {
    change_id = "",        -- ANSI codes for change ID
    commit_id = "",        -- ANSI codes for commit ID  
    author = "",           -- ANSI codes for author
    timestamp = "",        -- ANSI codes for timestamp
    description = "",      -- ANSI codes for description
    bookmarks = "",        -- ANSI codes for bookmarks
    graph = "",            -- ANSI codes for graph symbols
    empty_indicator = "",  -- ANSI codes for "(empty)" text
    conflict_indicator = "" -- ANSI codes for "conflict" text
  }

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

-- Get colored version of a field if color information is available
function Commit:get_colored_field(field_name, plain_text, reset)
  reset = reset or "\27[0m" -- Default reset code
  local color = self.colors[field_name]
  if color and color ~= "" then
    return color .. plain_text .. reset
  else
    return plain_text
  end
end

-- Get colored change ID
function Commit:get_colored_change_id(reset)
  local change_id = self.short_change_id or self.change_id:sub(1, 8)
  return self:get_colored_field("change_id", change_id, reset)
end

-- Get colored commit ID  
function Commit:get_colored_commit_id(reset)
  return self:get_colored_field("commit_id", self.short_commit_id, reset)
end

-- Get colored author
function Commit:get_colored_author(reset)
  return self:get_colored_field("author", self:get_author_display(), reset)
end

-- Get colored timestamp
function Commit:get_colored_timestamp(reset)
  return self:get_colored_field("timestamp", self:get_timestamp_display(), reset)
end

-- Get colored description
function Commit:get_colored_description(reset)
  return self:get_colored_field("description", self:get_short_description(), reset)
end

-- Get colored bookmarks
function Commit:get_colored_bookmarks(reset)
  return self:get_colored_field("bookmarks", self:get_bookmarks_display(), reset)
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

