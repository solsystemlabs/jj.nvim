#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Debug elided sections issue
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Debug Elided Sections Issue ===")

-- Get commits with elided sections
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 30 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

print("Total entries found: " .. #commits)

-- Check the first few entries and their types
for i = 1, math.min(10, #commits) do
  local entry = commits[i]
  print("\nEntry " .. i .. ":")
  print("  Type: " .. (entry.type or "commit"))
  
  if entry.type == "elided" then
    print("  Elided lines:")
    for j, line in ipairs(entry.lines or {}) do
      print("    " .. j .. ": " .. ansi.strip_ansi(line))
    end
  elseif entry.type == "connector" then
    print("  Connector lines:")
    for j, line in ipairs(entry.lines or {}) do
      print("    " .. j .. ": " .. ansi.strip_ansi(line))
    end
  else
    -- This is a commit
    print("  Commit ID: " .. (entry.short_commit_id or "unknown"))
    print("  Description: " .. (entry.description or "none"))
    if entry.complete_graph then
      print("  Graph: " .. ansi.strip_ansi(entry.complete_graph))
    end
  end
end

-- Test rendering a small subset
print("\n=== Rendering Test ===")
local test_entries = {}
for i = 1, math.min(8, #commits) do
  table.insert(test_entries, commits[i])
end

local lines = renderer.render_commits(test_entries, 'comfortable', 80)
for i, line in ipairs(lines) do
  print("Line " .. i .. ": " .. ansi.strip_ansi(line))
end