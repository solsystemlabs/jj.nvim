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

-- Factory function to create commits from template data
M.from_template_data = function(template_data)
  return Commit.new(template_data)
end

return M

