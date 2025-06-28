#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Final test of the empty commit fix
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Final Empty Commit Fix Test ===")

-- Get multiple commits
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 3 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Mark one as empty for testing
local test_commits = {}
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    table.insert(test_commits, entry)
    if #test_commits == 2 then
      -- Mark the second commit as empty for testing
      entry.empty = true
      break
    end
  end
end

print("Found " .. #test_commits .. " commits for testing")

-- Test rendering with normal width
print("\n=== Normal Width (120) ===")
local lines_normal = renderer.render_commits(test_commits, 'comfortable', 120)
for i, line in ipairs(lines_normal) do
  local clean = ansi.strip_ansi(line)
  print("Line " .. i .. ": " .. clean)
  if line:find('\27%[38;5;2m%(empty%)') then
    print("  ✓ Green (empty) detected!")
  end
end

-- Test rendering with narrow width to force wrapping
print("\n=== Narrow Width (60) - Forces Wrapping ===")
local lines_narrow = renderer.render_commits(test_commits, 'comfortable', 60)
for i, line in ipairs(lines_narrow) do
  local clean = ansi.strip_ansi(line)
  print("Line " .. i .. ": " .. clean)
  if line:find('\27%[38;5;2m%(empty%)') then
    print("  ✓ Green (empty) detected!")
  end
end

-- Verify positioning
print("\n=== Positioning Analysis ===")
local empty_line_found = false
for i, line in ipairs(lines_narrow) do
  local clean = ansi.strip_ansi(line)
  if clean:find("%(empty%)") then
    empty_line_found = true
    local graph_part = clean:match("^(.-│  )")
    local rest_part = clean:match("^.-│  (.*)$")
    if graph_part and rest_part then
      print("✓ Correct positioning found:")
      print("  Graph part: '" .. graph_part .. "'")
      print("  Rest part: '" .. rest_part .. "'")
      if rest_part:find("^%(empty%)") then
        print("  ✓ (empty) appears right after graph section!")
      else
        print("  ✗ (empty) not at start of rest part")
      end
    else
      print("✗ Could not parse graph structure")
    end
    break
  end
end

if not empty_line_found then
  print("✗ No empty line found")
else
  print("✓ Empty commit test completed successfully!")
end