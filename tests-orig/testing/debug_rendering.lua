#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Debug rendering with colors
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Debug Rendering with Colors ===")

-- Get commits with colors
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 1 })

if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find first real commit
local commit = nil
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    commit = entry
    break
  end
end

if not commit then
  print("ERROR: No commit found")
  os.exit(1)
end

print("Testing commit: " .. (commit.short_commit_id or "unknown"))

-- Test basic commit data
print("\nCommit data:")
print("  Change ID: " .. (commit.short_change_id or "unknown"))
print("  Commit ID: " .. (commit.short_commit_id or "unknown"))
print("  Author: " .. commit:get_author_display())
print("  Current: " .. (commit:is_current() and "yes" or "no"))

-- Test full rendering
print("\nFull rendering test:")
local lines = renderer.render_commits({commit}, 'comfortable', 120)
if lines and #lines > 0 then
  print("First rendered line:")
  print("  Raw: " .. lines[1]:gsub('\27', '\\27'))
  print("  Clean: " .. ansi.strip_ansi(lines[1]))
else
  print("No lines rendered")
end