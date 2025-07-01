#!/usr/bin/env lua

-- Test extracting clean commit IDs
local commit_test_call = 'jj log --limit 3 -T \'commit_id.short(8) ++ "\\n"\''
local handle = io.popen(commit_test_call)
local commit_result = handle:read("*a")
handle:close()

print("Raw commit output:")
print("'" .. commit_result .. "'")

print("\nExtracting commit IDs:")
local commit_ids = {}
for line in commit_result:gmatch("[^\n]+") do
  print("Line: '" .. line .. "'")
  
  -- Extract just the commit ID (8 hex chars)
  local commit_id = line:match("([a-f0-9]+)")
  if commit_id and #commit_id == 8 then
    table.insert(commit_ids, commit_id)
    print("  → Extracted: " .. commit_id)
  else
    print("  → No valid commit ID found")
  end
end

print("\nFinal commit IDs: [" .. table.concat(commit_ids, ", ") .. "]")

-- Test with one commit ID and bookmark matching
local test_commit = "4fea2b64"
print("\nTesting bookmark matching for commit: " .. test_commit)

-- Get bookmark data again
local template_call = 'jj bookmark list -a -T \'self.name() ++ "\\x1F" ++ if(self.remote(), self.remote(), "local") ++ "\\x1F" ++ if(self.present(), "present", "absent") ++ "\\x1F" ++ if(self.conflict(), "conflict", "clean") ++ "\\x1F" ++ if(self.present() && self.normal_target(), self.normal_target().commit_id().short(8), "no_commit") ++ "\\x1E"\''
local handle2 = io.popen(template_call)
local result = handle2:read("*a")
handle2:close()

local FIELD_SEP = "\x1F"
local RECORD_SEP = "\x1E"

local bookmarks = {}
for block in result:gmatch("[^" .. RECORD_SEP .. "]+") do
  if block ~= "" then
    local parts = {}
    for part in block:gmatch("[^" .. FIELD_SEP .. "]+") do
      table.insert(parts, part)
    end
    
    if #parts >= 5 then
      local bookmark = {
        name = parts[1],
        remote = parts[2] ~= "local" and parts[2] or nil,
        present = parts[3] == "present",
        commit_id = parts[5] ~= "no_commit" and parts[5] or nil
      }
      table.insert(bookmarks, bookmark)
    end
  end
end

print("Testing matches:")
for _, bookmark in ipairs(bookmarks) do
  if bookmark.commit_id then
    print(string.format("Bookmark %s: commit_id='%s'", bookmark.name, bookmark.commit_id))
    
    if bookmark.commit_id == test_commit then
      print("  ✓ EXACT match")
    elseif bookmark.commit_id:find("^" .. test_commit) then
      print("  ✓ PREFIX match") 
    else
      print("  ✗ No match")
    end
  else
    print(string.format("Bookmark %s: no commit_id", bookmark.name))
  end
end