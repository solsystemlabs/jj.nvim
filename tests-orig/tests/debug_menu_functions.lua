#!/usr/bin/env lua

-- Debug the menu functions specifically
print("=== Debugging Bookmark Menu Functions ===")

-- Get actual bookmark data using the same template
local template_call = 'jj bookmark list -a -T \'self.name() ++ "\\x1F" ++ if(self.remote(), self.remote(), "local") ++ "\\x1F" ++ if(self.present(), "present", "absent") ++ "\\x1F" ++ if(self.conflict(), "conflict", "clean") ++ "\\x1F" ++ if(self.present() && self.normal_target(), self.normal_target().commit_id().short(8), "no_commit") ++ "\\x1E"\''

local handle = io.popen(template_call)
local result = handle:read("*a")
handle:close()

local FIELD_SEP = "\x1F"
local RECORD_SEP = "\x1E"

-- Parse bookmarks exactly like the new code does
local all_bookmarks = {}
local bookmark_blocks = {}

for block in result:gmatch("[^" .. RECORD_SEP .. "]+") do
  if block ~= "" then
    table.insert(bookmark_blocks, block)
  end
end

for _, bookmark_block in ipairs(bookmark_blocks) do
  local trimmed_block = bookmark_block:match("^%s*(.-)%s*$")
  
  if trimmed_block ~= "" and not trimmed_block:match("^Hint:") then
    local parts = {}
    for part in trimmed_block:gmatch("[^" .. FIELD_SEP .. "]+") do
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
      
      -- Generate display name exactly like the code
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
      
      table.insert(all_bookmarks, bookmark)
    end
  end
end

print("All parsed bookmarks:")
for i, bookmark in ipairs(all_bookmarks) do
  print(string.format("  %d: %s (name=%s, remote=%s, present=%s, conflict=%s)", 
    i, bookmark.display_name, bookmark.name, bookmark.remote or "nil", 
    tostring(bookmark.present), tostring(bookmark.conflict)))
end

-- Test get_remote_bookmarks logic
print("\nTesting get_remote_bookmarks():")
local remote_bookmarks = {}
for _, bookmark in ipairs(all_bookmarks) do
  if bookmark.remote and bookmark.present then
    table.insert(remote_bookmarks, bookmark)
  end
end

print("Remote bookmarks for menu:")
for i, bookmark in ipairs(remote_bookmarks) do
  print(string.format("  %d: %s", i, bookmark.display_name))
end

-- Test get_local_bookmarks logic  
print("\nTesting get_local_bookmarks():")
local local_bookmarks = {}
for _, bookmark in ipairs(all_bookmarks) do
  if not bookmark.remote and bookmark.present then
    table.insert(local_bookmarks, bookmark)
  end
end

print("Local bookmarks for menu:")
for i, bookmark in ipairs(local_bookmarks) do
  print(string.format("  %d: %s", i, bookmark.display_name))
end

-- Test get_all_present_bookmarks logic
print("\nTesting get_all_present_bookmarks():")
local present_bookmarks = {}
for _, bookmark in ipairs(all_bookmarks) do
  if bookmark.present then
    table.insert(present_bookmarks, bookmark)
  end
end

print("All present bookmarks for menu:")
for i, bookmark in ipairs(present_bookmarks) do
  print(string.format("  %d: %s", i, bookmark.display_name))
end