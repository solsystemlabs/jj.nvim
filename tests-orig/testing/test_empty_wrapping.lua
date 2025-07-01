#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test empty commit description wrapping
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Test Empty Description Wrapping ===")

-- Get commits
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 5 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find an empty commit
local empty_commit = nil
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" and entry.empty then
    empty_commit = entry
    break
  end
end

if not empty_commit then
  print("No empty commit found, testing with first commit marked as empty")
  for _, entry in ipairs(commits) do
    if entry.type ~= "elided" and entry.type ~= "connector" then
      empty_commit = entry
      empty_commit.empty = true  -- Force it to be empty for testing
      break
    end
  end
end

if not empty_commit then
  print("ERROR: No commit found")
  os.exit(1)
end

print("Testing with commit: " .. (empty_commit.short_commit_id or "unknown"))
print("Empty status: " .. (empty_commit.empty and "yes" or "no"))

-- Test the new methods
print("\nTesting new methods:")
print("get_short_description(): '" .. empty_commit:get_short_description() .. "'")
print("get_description_text_only(): '" .. empty_commit:get_description_text_only() .. "'")

-- Test rendering with normal width
print("\nNormal width (120):")
local lines_normal = renderer.render_commits({empty_commit}, 'comfortable', 120)
for i, line in ipairs(lines_normal) do
  print("Line " .. i .. ": " .. line:gsub('\27', '\\27'))
  print("Clean " .. i .. ": " .. ansi.strip_ansi(line))
end

-- Test rendering with narrow width to force wrapping
print("\nNarrow width (50) to force wrapping:")
local lines_narrow = renderer.render_commits({empty_commit}, 'comfortable', 50)
for i, line in ipairs(lines_narrow) do
  print("Line " .. i .. ": " .. line:gsub('\27', '\\27'))
  print("Clean " .. i .. ": " .. ansi.strip_ansi(line))
end

-- Check if (empty) appears in green
print("\nChecking for green (empty) indicator:")
local found_green_empty = false
for i, line in ipairs(lines_narrow) do
  if line:find('\27%[38;5;2m%(empty%)') then
    print("✓ Found green (empty) in line " .. i)
    found_green_empty = true
  end
end

if not found_green_empty then
  print("✗ No green (empty) found!")
else
  print("✓ Test passed!")
end