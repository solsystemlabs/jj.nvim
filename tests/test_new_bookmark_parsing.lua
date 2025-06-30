#!/usr/bin/env lua

-- Test the new template-based bookmark parsing
local sample_template_output = "master\x1flocal\x1fpresent\x1fclean\x1funtracked\x1f4fea2b64\x1emaster\x1forigin\x1fpresent\x1fclean\x1ftracked\x1f4fea2b64\x1ereal-work\x1flocal\x1fabsent\x1fclean\x1funtracked\x1fno_commit\x1ereal-work\x1forigin\x1fpresent\x1fclean\x1ftracked\x1f8e92528a\x1etest\x1flocal\x1fabsent\x1fclean\x1funtracked\x1fno_commit\x1etest\x1forigin\x1fpresent\x1fclean\x1ftracked\x1f4b76baa5\x1etest-delete\x1flocal\x1fpresent\x1fclean\x1funtracked\x1fd97a04e9\x1e"

-- Mock the bookmark module structures  
local BOOKMARK_TYPES = {
  LOCAL = "local",
  REMOTE = "remote",
  CONFLICTED = "conflicted"
}

local BOOKMARK_STATUS = {
  CLEAN = "clean", 
  CONFLICTED = "conflicted",
  OUT_OF_SYNC = "out_of_sync"
}

local function new_bookmark(name, bookmark_type, target_commit, remote_name, status)
  return {
    name = name,
    type = bookmark_type or BOOKMARK_TYPES.LOCAL,
    target_commit = target_commit,
    remote_name = remote_name,
    status = status or BOOKMARK_STATUS.CLEAN,
    
    is_conflicted = function(self)
      return self.type == BOOKMARK_TYPES.CONFLICTED or self.status == BOOKMARK_STATUS.CONFLICTED
    end,
    
    get_display_name = function(self)
      local base_name = self.name
      if self.type == BOOKMARK_TYPES.REMOTE then
        base_name = string.format("%s@%s", self.name, self.remote_name or "origin")
      end
      
      -- Add status indicators
      local status_indicators = {}
      
      -- Add presence indicator (for absent/deleted bookmarks)
      if self.present == false then
        table.insert(status_indicators, "deleted")
      end
      
      -- Add conflict indicator
      if self:is_conflicted() then
        table.insert(status_indicators, "conflict")
      end
      
      -- Add tracking indicator for remote bookmarks
      if self.type == BOOKMARK_TYPES.REMOTE and self.tracking_status == "untracked" then
        table.insert(status_indicators, "untracked")
      end
      
      -- Combine base name with status indicators
      if #status_indicators > 0 then
        return string.format("%s (%s)", base_name, table.concat(status_indicators, ", "))
      end
      
      return base_name
    end
  }
end

-- Parse template output (mimicking the new parsing logic)
local function parse_template_bookmarks(template_output)
  local FIELD_SEP = "\x1F"  -- Unit Separator 
  local RECORD_SEP = "\x1E" -- Record Separator
  
  local bookmarks = {}
  local bookmark_blocks = {}
  for block in template_output:gmatch("[^" .. RECORD_SEP .. "]+") do
    table.insert(bookmark_blocks, block)
  end
  
  for _, bookmark_block in ipairs(bookmark_blocks) do
    local trimmed_block = bookmark_block:match("^%s*(.-)%s*$") -- trim whitespace
    
    if trimmed_block ~= "" then
      local parts = {}
      for part in trimmed_block:gmatch("[^" .. FIELD_SEP .. "]+") do
        table.insert(parts, part)
      end
      
      if #parts >= 6 then
        local name = parts[1] or ""
        local remote_type = parts[2] or ""
        local presence = parts[3] or ""
        local conflict_status = parts[4] or ""
        local tracking_status = parts[5] or ""
        local commit_id = parts[6] or ""
        
        -- Determine bookmark type
        local bookmark_type = BOOKMARK_TYPES.LOCAL
        local remote_name = nil
        
        if remote_type ~= "local" then
          bookmark_type = BOOKMARK_TYPES.REMOTE
          remote_name = remote_type
        end
        
        -- Determine status
        local status = BOOKMARK_STATUS.CLEAN
        if conflict_status == "conflict" then
          status = BOOKMARK_STATUS.CONFLICTED
          bookmark_type = BOOKMARK_TYPES.CONFLICTED
        end
        
        -- Create target commit info if present
        local target_commit = nil
        if presence == "present" and commit_id ~= "no_commit" then
          target_commit = { id = commit_id }
        end
        
        -- Create bookmark object
        local bookmark = new_bookmark(
          name,
          bookmark_type,
          target_commit,
          remote_name,
          status
        )
        
        -- Add additional metadata
        bookmark.present = presence == "present"
        bookmark.tracking_status = tracking_status
        
        table.insert(bookmarks, bookmark)
      end
    end
  end
  
  return bookmarks
end

-- Test deduplication logic  
local function test_deduplication(commit_bookmarks)
  -- Smart deduplication logic
  local bookmark_groups = {}
  
  -- Group bookmarks by name
  for _, bookmark in ipairs(commit_bookmarks) do
    local name = bookmark.name
    if not bookmark_groups[name] then
      bookmark_groups[name] = { local_bookmark = nil, remote_bookmarks = {} }
    end
    
    if bookmark.type == "local" then
      bookmark_groups[name].local_bookmark = bookmark
    else
      table.insert(bookmark_groups[name].remote_bookmarks, bookmark)
    end
  end
  
  -- Apply deduplication rules
  local bookmark_parts = {}
  for name, group in pairs(bookmark_groups) do
    local local_bookmark = group.local_bookmark
    local remote_bookmarks = group.remote_bookmarks
    
    if local_bookmark and local_bookmark.present then
      -- Local bookmark is present - show only local name
      table.insert(bookmark_parts, local_bookmark:get_display_name())
    elseif local_bookmark and not local_bookmark.present then
      -- Local bookmark is absent (deleted) - show remote bookmarks
      for _, remote_bookmark in ipairs(remote_bookmarks) do
        if remote_bookmark.present then
          table.insert(bookmark_parts, remote_bookmark:get_display_name())
        end
      end
    else
      -- No local bookmark - show remote bookmarks
      for _, remote_bookmark in ipairs(remote_bookmarks) do
        if remote_bookmark.present then
          table.insert(bookmark_parts, remote_bookmark:get_display_name())
        end
      end
    end
  end
  
  return table.concat(bookmark_parts, " ")
end

-- Test the parsing
print("Testing new template-based bookmark parsing...")
local bookmarks = parse_template_bookmarks(sample_template_output)

print("Found " .. #bookmarks .. " bookmarks:")
for i, bookmark in ipairs(bookmarks) do
  print(string.format("%d: %s (type: %s, remote: %s, present: %s, display: %s, commit: %s)", 
    i, 
    bookmark.name, 
    bookmark.type, 
    bookmark.remote_name or "none",
    tostring(bookmark.present),
    bookmark:get_display_name(),
    bookmark.target_commit and bookmark.target_commit.id or "none"))
end

-- Test commit-specific lookups
print("\nTesting deduplication for commit 4fea2b64...")
local commit_4fea2b64_bookmarks = {}
for _, bookmark in ipairs(bookmarks) do
  if bookmark.target_commit and bookmark.target_commit.id == "4fea2b64" then
    table.insert(commit_4fea2b64_bookmarks, bookmark)
  end
end
local display_4fea2b64 = test_deduplication(commit_4fea2b64_bookmarks)
print("Display for 4fea2b64: '" .. display_4fea2b64 .. "'")

print("\nTesting deduplication for commit 8e92528a...")
local commit_8e92528a_bookmarks = {}
for _, bookmark in ipairs(bookmarks) do
  if bookmark.target_commit and bookmark.target_commit.id == "8e92528a" then
    table.insert(commit_8e92528a_bookmarks, bookmark)
  end
end
local display_8e92528a = test_deduplication(commit_8e92528a_bookmarks)
print("Display for 8e92528a: '" .. display_8e92528a .. "'")

print("\nTesting deduplication for commit d97a04e9...")
local commit_d97a04e9_bookmarks = {}
for _, bookmark in ipairs(bookmarks) do
  if bookmark.target_commit and bookmark.target_commit.id == "d97a04e9" then
    table.insert(commit_d97a04e9_bookmarks, bookmark)
  end
end
local display_d97a04e9 = test_deduplication(commit_d97a04e9_bookmarks)
print("Display for d97a04e9: '" .. display_d97a04e9 .. "'")