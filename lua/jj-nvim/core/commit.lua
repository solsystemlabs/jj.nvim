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
  self.line_start = nil    -- First line in display buffer
  self.line_end = nil      -- Last line in display buffer
  self.header_line = nil   -- Main commit line for navigation
  self.lines = {}          -- Display lines for this commit
  
  return self
end

-- Get the display symbol for this commit (@ for current, ○ for others, ◆ for root)
function Commit:get_symbol()
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
  if not self.description or self.description == "" then
    return "(no description set)"
  end
  
  local first_line = self.description:match("([^\n]*)")
  return first_line or self.description
end

-- Get full description with proper line breaks
function Commit:get_full_description()
  if not self.description or self.description == "" then
    return "(no description set)"
  end
  return self.description
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

-- Get a compact single-line representation
function Commit:get_compact_line()
  local parts = {}
  
  -- Symbol and change ID
  table.insert(parts, self:get_symbol())
  table.insert(parts, " ")
  table.insert(parts, self.short_change_id or self.change_id:sub(1, 8))
  
  -- Author
  local author = self:get_author_display()
  if author ~= "" then
    table.insert(parts, " ")
    table.insert(parts, author)
  end
  
  -- Timestamp
  local timestamp = self:get_timestamp_display()
  if timestamp ~= "" then
    table.insert(parts, " ")
    table.insert(parts, timestamp)
  end
  
  -- Commit ID
  if self.short_commit_id ~= "" then
    table.insert(parts, " ")
    table.insert(parts, self.short_commit_id)
  end
  
  return table.concat(parts)
end

-- Get multi-line representation for detailed view
function Commit:get_detailed_lines()
  local lines = {}
  
  -- Main commit line
  table.insert(lines, self:get_compact_line())
  
  -- Description (indented)
  local description = self:get_short_description()
  if description ~= "" then
    table.insert(lines, "│  " .. description)
  end
  
  -- Bookmarks (if any)
  local bookmarks = self:get_bookmarks_display()
  if bookmarks ~= "" then
    table.insert(lines, "│  bookmarks: " .. bookmarks)
  end
  
  return lines
end

-- Factory function to create commits from template data
M.from_template_data = function(template_data)
  return Commit.new(template_data)
end

-- Create a list of commits from an array of template data
M.from_template_array = function(template_array)
  local commits = {}
  for _, data in ipairs(template_array) do
    table.insert(commits, M.from_template_data(data))
  end
  return commits
end

return M