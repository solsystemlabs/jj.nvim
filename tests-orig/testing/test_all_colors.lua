#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test the complete color preservation pipeline
local parser = require('jj-nvim.core.parser')

print("=== Testing All Color Fields ===")

-- Test parsing with colors
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 3 })

if err then
  print("ERROR: Failed to parse commits: " .. err)
  os.exit(1)
end

if not commits or #commits == 0 then
  print("ERROR: No commits returned")
  os.exit(1)
end

print("✓ Parsed " .. #commits .. " commits")

-- Check all color fields for each commit
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    local commit_id = entry.short_commit_id or "unknown"
    print("\nCommit " .. commit_id .. ":")
    
    if entry.colors then
      for field, color in pairs(entry.colors) do
        if color and color ~= "" then
          print("  " .. field .. ": '" .. color:gsub('\27', '\\27') .. "'")
        else
          print("  " .. field .. ": (empty)")
        end
      end
    else
      print("  No colors table")
    end
  end
end