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

-- Show stored colors
print("\nStored colors:")
for field, color in pairs(commit.colors or {}) do
  if color and color ~= "" then
    print("  " .. field .. ": '" .. color:gsub('\27', '\\27') .. "'")
  end
end

-- Test individual field coloring
print("\nTesting field coloring:")

-- Test change ID
local change_id_text = commit.short_change_id or "test"
local change_id_colored = commit:get_colored_change_id()
print("Change ID:")
print("  Plain: '" .. change_id_text .. "'")
print("  Colored: '" .. change_id_colored:gsub('\27', '\\27') .. "'")
print("  Same? " .. (change_id_text == change_id_colored and "YES" or "NO"))

-- Test commit ID
local commit_id_colored = commit:get_colored_commit_id()
print("Commit ID:")
print("  Plain: '" .. commit.short_commit_id .. "'")
print("  Colored: '" .. commit_id_colored:gsub('\27', '\\27') .. "'")

-- Test author
local author_colored = commit:get_colored_author()
print("Author:")
print("  Plain: '" .. commit:get_author_display() .. "'")
print("  Colored: '" .. author_colored:gsub('\27', '\\27') .. "'")

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