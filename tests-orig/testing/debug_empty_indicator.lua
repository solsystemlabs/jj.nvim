#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Debug empty indicator insertion
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Debug Empty Indicator Insertion ===")

-- Get commits
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 1 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find first real commit and mark as empty
local commit = nil
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    commit = entry
    commit.empty = true  -- Force it to be empty for testing
    break
  end
end

if not commit then
  print("ERROR: No commit found")
  os.exit(1)
end

print("Testing with commit: " .. (commit.short_commit_id or "unknown"))
print("Empty status: " .. (commit.empty and "yes" or "no"))

-- Test description methods
print("\nDescription methods:")
print("get_description_text_only(): '" .. commit:get_description_text_only() .. "'")

-- Render with narrow width
local lines = renderer.render_commits({commit}, 'comfortable', 50)
print("\nRendered lines:")
for i, line in ipairs(lines) do
  local clean = ansi.strip_ansi(line)
  print("Line " .. i .. " (clean): " .. clean)
  print("Line " .. i .. " (raw):   " .. line:gsub('\27', '\\27'))
  
  -- Check for description colors
  if line:find('\27%[1m\27%[38;5;3m') or line:find('\27%[38;5;3m') then
    print("  ✓ Description color found")
  end
  
  -- Check for empty indicator
  if line:find('\27%[38;5;2m%(empty%)') then
    print("  ✓ Empty indicator found")
  end
end