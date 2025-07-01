#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test empty commits with long descriptions
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Test Empty Commits with Long Descriptions ===")

-- Get commits
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 1 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find first real commit and make it empty with long description
local test_commit = nil
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    test_commit = entry
    test_commit.empty = true
    test_commit.description = "really long really long long long lsdjf lsdkjf lskjdfk lskdjjfkdl sldkfj lskdj flskdj flkjdkfjsld jlsdkfjksdjf lksjd fl"
    test_commit.full_description = test_commit.description
    break
  end
end

if not test_commit then
  print("ERROR: No commit found")
  os.exit(1)
end

print("Testing empty commit: " .. (test_commit.short_commit_id or "unknown"))
print("Empty status: " .. (test_commit.empty and "yes" or "no"))
print("Description: " .. test_commit.description)

-- Test rendering with narrow width to force wrapping
print("\n=== Narrow Width (50) - Forces Wrapping ===")
local lines_narrow = renderer.render_commits({test_commit}, 'comfortable', 50)
for i, line in ipairs(lines_narrow) do
  local clean = ansi.strip_ansi(line)
  print("Line " .. i .. ": " .. clean)
  print("  Width: " .. vim.fn.strdisplaywidth(clean))
  
  -- Check for empty indicator
  if line:find('\27%[38;5;2m%(empty%)') then
    print("  ✓ Green (empty) indicator found!")
  end
end

-- Check if any line exceeds the window width
print("\n=== Width Analysis ===")
local max_width = 50
local violations = 0
local empty_found = false
for i, line in ipairs(lines_narrow) do
  local clean = ansi.strip_ansi(line)
  local width = vim.fn.strdisplaywidth(clean)
  if width > max_width then
    print("✗ Line " .. i .. " exceeds width (" .. width .. " > " .. max_width .. "): " .. clean)
    violations = violations + 1
  end
  
  if clean:find("%(empty%)") then
    empty_found = true
  end
end

if violations == 0 then
  print("✓ All lines respect the width limit!")
else
  print("✗ Found " .. violations .. " width violations")
end

if empty_found then
  print("✓ Empty indicator found in wrapped output!")
else
  print("✗ Empty indicator not found!")
end