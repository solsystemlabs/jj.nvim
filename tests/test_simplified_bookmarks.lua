#!/usr/bin/env lua

-- Test simplified bookmark approach
local sample_template_output = "master\x1flocal\x1fpresent\x1fclean\x1f4fea2b64\x1emaster\x1forigin\x1fpresent\x1fclean\x1f4fea2b64\x1ereal-work\x1flocal\x1fabsent\x1fclean\x1fno_commit\x1ereal-work\x1forigin\x1fpresent\x1fclean\x1f8e92528a\x1etest\x1flocal\x1fabsent\x1fclean\x1fno_commit\x1etest\x1forigin\x1fpresent\x1fclean\x1f4b76baa5\x1etest-delete\x1flocal\x1fpresent\x1fclean\x1fd97a04e9\x1e"

local FIELD_SEP = "\x1F"
local RECORD_SEP = "\x1E"

-- Simplified parsing
local function parse_simple_bookmarks(template_output)
  local bookmarks = {}
  local bookmark_blocks = {}
  for block in template_output:gmatch("[^" .. RECORD_SEP .. "]+") do
    if block ~= "" then
      table.insert(bookmark_blocks, block)
    end
  end

  for _, bookmark_block in ipairs(bookmark_blocks) do
    local parts = {}
    for part in bookmark_block:gmatch("[^" .. FIELD_SEP .. "]+") do
      table.insert(parts, part)
    end
    
    if #parts >= 5 then
      local bookmark = {
        name = parts[1] or "",
        remote = parts[2] ~= "local" and parts[2] or nil,
        present = parts[3] == "present",
        conflict = parts[4] == "conflict", 
        commit_id = parts[5] ~= "no_commit" and parts[5] or nil
      }
      
      -- Generate display name
      if bookmark.remote then
        bookmark.display_name = bookmark.name .. "@" .. bookmark.remote
      else
        bookmark.display_name = bookmark.name
      end
      
      -- Add status indicators
      local status_parts = {}
      if not bookmark.present then
        table.insert(status_parts, "deleted")
      end
      if bookmark.conflict then
        table.insert(status_parts, "conflict")
      end
      
      if #status_parts > 0 then
        bookmark.display_name = bookmark.display_name .. " (" .. table.concat(status_parts, ", ") .. ")"
      end
      
      table.insert(bookmarks, bookmark)
    end
  end
  
  return bookmarks
end

-- Test commit display logic
local function test_commit_display(bookmarks, commit_id)
  local commit_bookmarks = {}
  
  for _, bookmark in ipairs(bookmarks) do
    if bookmark.commit_id and bookmark.present then
      if bookmark.commit_id == commit_id or bookmark.commit_id:find("^" .. commit_id) then
        table.insert(commit_bookmarks, bookmark)
      end
    end
  end
  
  if #commit_bookmarks == 0 then
    return ""
  end
  
  -- Simple deduplication: prefer local over remote for same name
  local bookmark_map = {}
  local display_parts = {}
  
  -- First pass: collect local bookmarks
  for _, bookmark in ipairs(commit_bookmarks) do
    if not bookmark.remote then
      bookmark_map[bookmark.name] = true
      table.insert(display_parts, bookmark.display_name)
    end
  end
  
  -- Second pass: add remote bookmarks only if no local exists
  for _, bookmark in ipairs(commit_bookmarks) do
    if bookmark.remote and not bookmark_map[bookmark.name] then
      table.insert(display_parts, bookmark.display_name)
    end
  end
  
  return table.concat(display_parts, " ")
end

-- Test filtering functions
local function get_local_bookmarks(bookmarks)
  local local_bookmarks = {}
  for _, bookmark in ipairs(bookmarks) do
    if not bookmark.remote and bookmark.present then
      table.insert(local_bookmarks, bookmark.display_name)
    end
  end
  return local_bookmarks
end

local function get_remote_bookmarks(bookmarks)
  local remote_bookmarks = {}
  for _, bookmark in ipairs(bookmarks) do
    if bookmark.remote and bookmark.present then
      table.insert(remote_bookmarks, bookmark.display_name)
    end
  end
  return remote_bookmarks
end

-- Run tests
print("=== Testing Simplified Bookmark Approach ===")

local bookmarks = parse_simple_bookmarks(sample_template_output)

print("All bookmarks:")
for i, bookmark in ipairs(bookmarks) do
  print(string.format("  %d: %s (remote: %s, present: %s, commit: %s)", 
    i, bookmark.display_name, bookmark.remote or "none", 
    tostring(bookmark.present), bookmark.commit_id or "none"))
end

print("\nCommit display tests:")
local test_commits = {"4fea2b64", "8e92528a", "d97a04e9", "nonexistent"}
for _, commit_id in ipairs(test_commits) do
  local display = test_commit_display(bookmarks, commit_id)
  print(string.format("  %s: '%s'", commit_id, display))
end

print("\nMenu filtering tests:")
local local_bookmarks = get_local_bookmarks(bookmarks)
print("Local bookmarks: [" .. table.concat(local_bookmarks, ", ") .. "]")

local remote_bookmarks = get_remote_bookmarks(bookmarks)
print("Remote bookmarks: [" .. table.concat(remote_bookmarks, ", ") .. "]")