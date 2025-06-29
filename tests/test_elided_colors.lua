#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test elided sections color rendering
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Test Elided Sections Colors ===")

-- Get commits with elided sections
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 15 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find elided sections
local elided_entries = {}
for i, entry in ipairs(commits) do
  if entry.type == "elided" then
    table.insert(elided_entries, { index = i, entry = entry })
  end
end

print("Found " .. #elided_entries .. " elided sections")

-- Test rendering a subset that includes elided sections
local test_entries = {}
for i = 1, math.min(10, #commits) do
  table.insert(test_entries, commits[i])
end

local lines = renderer.render_commits(test_entries, 'comfortable', 80)

-- Find and show elided lines with their raw ANSI codes
print("\n=== Elided Lines with Colors ===")
for i, line in ipairs(lines) do
  local clean_line = ansi.strip_ansi(line)
  if clean_line:match("%(elided revisions%)") or clean_line:match("^~") then
    print("Line " .. i .. " (raw with ANSI): " .. line)
    print("Line " .. i .. " (clean): " .. clean_line)
    print("Line " .. i .. " (hex dump):")
    
    -- Show hex representation of ANSI codes
    for j = 1, #line do
      local byte = line:byte(j)
      local char = line:sub(j, j)
      if byte == 27 then -- ESC character
        io.write("\\033")
      elseif byte >= 32 and byte <= 126 then -- Printable ASCII
        io.write(char)
      else
        io.write(string.format("\\x%02x", byte))
      end
    end
    print("\n")
  end
end