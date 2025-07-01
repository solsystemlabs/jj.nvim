#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test structured elided sections implementation
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Test Structured Elided Sections ===")

-- Get commits with elided sections
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 15 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Test that elided entries are proper objects with methods
local elided_count = 0
for i, entry in ipairs(commits) do
  if entry.type == "elided" then
    elided_count = elided_count + 1
    
    print("\nElided entry " .. elided_count .. ":")
    print("  Type: " .. entry.type)
    print("  Has get_all_line_parts method: " .. tostring(type(entry.get_all_line_parts) == "function"))
    
    -- Test the structured parts
    local all_line_parts = entry:get_all_line_parts()
    print("  Number of lines: " .. #all_line_parts)
    
    for line_idx, line_parts in ipairs(all_line_parts) do
      print("    Line " .. line_idx .. " has " .. #line_parts .. " parts:")
      for part_idx, part in ipairs(line_parts) do
        print("      Part " .. part_idx .. ": type='" .. part.type .. "', text='" .. part.text .. "', visible=" .. tostring(part.visible))
      end
    end
  end
end

print("\nFound " .. elided_count .. " elided sections with structured parts")

-- Test full rendering
print("\n=== Full Rendering Test ===")
local test_entries = {}
for i = 1, math.min(8, #commits) do
  table.insert(test_entries, commits[i])
end

local lines = renderer.render_commits(test_entries, 'comfortable', 80)

-- Show context around elided lines
local elided_line_numbers = {}
for i, line in ipairs(lines) do
  local clean_line = ansi.strip_ansi(line)
  if clean_line:match("%(elided revisions%)") or clean_line:match("^~") then
    table.insert(elided_line_numbers, i)
  end
end

print("Elided lines found at: " .. table.concat(elided_line_numbers, ", "))

-- Show one elided line in context
if #elided_line_numbers > 0 then
  local elided_line_num = elided_line_numbers[1]
  local start_line = math.max(1, elided_line_num - 1)
  local end_line = math.min(#lines, elided_line_num + 1)
  
  print("\nContext around line " .. elided_line_num .. ":")
  for i = start_line, end_line do
    local marker = (i == elided_line_num) and " >>> " or "     "
    local clean_line = ansi.strip_ansi(lines[i])
    print(marker .. "Line " .. i .. ": '" .. clean_line .. "'")
  end
end