#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test wrapping with long descriptions
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Test Wrapping with Long Descriptions ===")

-- Get commits
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 10 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find a commit with a long description or create one
local test_commit = nil
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    test_commit = entry
    break
  end
end

if not test_commit then
  print("ERROR: No commit found")
  os.exit(1)
end

-- Create a commit with a very long description
test_commit.description = "really long really long long long lsdjf lsdkjf lskjdfk lskdjjfkdl sldkfj lskdj flskdj flkjdkfjsld jlsdkfjksdjf lksjd fl"
test_commit.full_description = test_commit.description

print("Testing with commit: " .. (test_commit.short_commit_id or "unknown"))
print("Description: " .. test_commit.description)

-- Test rendering with narrow width to force wrapping
print("\n=== Narrow Width (60) - Forces Wrapping ===")
local lines_narrow = renderer.render_commits({test_commit}, 'comfortable', 60)
for i, line in ipairs(lines_narrow) do
  local clean = ansi.strip_ansi(line)
  print("Line " .. i .. ": " .. clean)
  print("  Width: " .. vim.fn.strdisplaywidth(clean))
end

-- Test with even narrower width
print("\n=== Very Narrow Width (40) - Forces More Wrapping ===")
local lines_very_narrow = renderer.render_commits({test_commit}, 'comfortable', 40)
for i, line in ipairs(lines_very_narrow) do
  local clean = ansi.strip_ansi(line)
  print("Line " .. i .. ": " .. clean)
  print("  Width: " .. vim.fn.strdisplaywidth(clean))
end

-- Check if any line exceeds the window width
print("\n=== Width Analysis ===")
local max_width = 40
local violations = 0
for i, line in ipairs(lines_very_narrow) do
  local clean = ansi.strip_ansi(line)
  local width = vim.fn.strdisplaywidth(clean)
  if width > max_width then
    print("✗ Line " .. i .. " exceeds width (" .. width .. " > " .. max_width .. "): " .. clean)
    violations = violations + 1
  end
end

if violations == 0 then
  print("✓ All lines respect the width limit!")
else
  print("✗ Found " .. violations .. " width violations")
end