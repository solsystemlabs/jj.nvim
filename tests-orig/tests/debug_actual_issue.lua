#!/usr/bin/env lua

-- Let's debug what's actually happening with the real data
print("=== Debugging Actual Issue ===")

-- Simulate the actual template call
local template_call = 'jj bookmark list -a -T \'self.name() ++ "\\x1F" ++ if(self.remote(), self.remote(), "local") ++ "\\x1F" ++ if(self.present(), "present", "absent") ++ "\\x1F" ++ if(self.conflict(), "conflict", "clean") ++ "\\x1F" ++ if(self.present() && self.normal_target(), self.normal_target().commit_id().short(8), "no_commit") ++ "\\x1E"\''

print("Template call:")
print(template_call)

-- Get actual output
local handle = io.popen(template_call)
local result = handle:read("*a")
handle:close()

print("\nRaw template result length: " .. #result)
print("First 200 chars as hex:")
for i = 1, math.min(200, #result) do
  local char = result:sub(i, i)
  local byte = string.byte(char)
  if byte == 0x1F then
    io.write("|")
  elseif byte == 0x1E then  
    io.write("⟩")
  elseif byte >= 32 and byte <= 126 then
    io.write(char)
  else
    io.write(string.format("\\x%02x", byte))
  end
end
print()

-- Parse it the same way the code does
local FIELD_SEP = "\x1F"
local RECORD_SEP = "\x1E"

local bookmarks = {}
local bookmark_blocks = {}

-- Split on record separator
for block in result:gmatch("[^" .. RECORD_SEP .. "]+") do
  if block ~= "" then
    table.insert(bookmark_blocks, block)
  end
end

print("\nFound " .. #bookmark_blocks .. " bookmark blocks")

for i, bookmark_block in ipairs(bookmark_blocks) do
  local trimmed_block = bookmark_block:match("^%s*(.-)%s*$")
  
  if trimmed_block ~= "" and not trimmed_block:match("^Hint:") then
    local parts = {}
    for part in trimmed_block:gmatch("[^" .. FIELD_SEP .. "]+") do
      table.insert(parts, part)
    end
    
    print(string.format("Block %d: %d parts: [%s]", i, #parts, table.concat(parts, ", ")))
    
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
      print(string.format("  → %s", bookmark.display_name))
    end
  end
end

-- Test with actual current commit IDs
local commit_test_call = 'jj log --limit 3 -T \'commit_id.short(8) ++ "\\n"\''
local handle2 = io.popen(commit_test_call)
local commit_result = handle2:read("*a")
handle2:close()

local commit_ids = {}
for line in commit_result:gmatch("[^\n]+") do
  local commit_id = line:match("^%s*(.-)%s*$")
  if commit_id ~= "" then
    table.insert(commit_ids, commit_id)
  end
end

print("\nTesting with actual commit IDs:")
for i, commit_id in ipairs(commit_ids) do
  print(string.format("Commit %d: %s", i, commit_id))
  
  -- Test bookmark matching
  local matching_bookmarks = {}
  for _, bookmark in ipairs(bookmarks) do
    if bookmark.commit_id and bookmark.present then
      if bookmark.commit_id == commit_id or bookmark.commit_id:find("^" .. commit_id) then
        table.insert(matching_bookmarks, bookmark)
      end
    end
  end
  
  print(string.format("  Found %d matching bookmarks:", #matching_bookmarks))
  for _, bookmark in ipairs(matching_bookmarks) do
    print(string.format("    - %s", bookmark.display_name))
  end
  
  -- Test display logic
  if #matching_bookmarks > 0 then
    local bookmark_map = {}
    local display_parts = {}
    
    -- First pass: collect local bookmarks
    for _, bookmark in ipairs(matching_bookmarks) do
      if not bookmark.remote then
        bookmark_map[bookmark.name] = true
        table.insert(display_parts, bookmark.display_name)
      end
    end
    
    -- Second pass: add remote bookmarks only if no local exists
    for _, bookmark in ipairs(matching_bookmarks) do
      if bookmark.remote and not bookmark_map[bookmark.name] then
        table.insert(display_parts, bookmark.display_name)
      end
    end
    
    local final_display = table.concat(display_parts, " ")
    print(string.format("  Final display: '%s'", final_display))
  else
    print("  Final display: ''")
  end
  print()
end