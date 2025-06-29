#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test with wider window to see if wrapping is less aggressive
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Test Wider Window Wrapping ===")

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

-- Test with various window widths to show improved wrapping
local widths = {60, 80, 100, 120}

for _, width in ipairs(widths) do
  print("\n=== Width " .. width .. " ===")
  local lines = renderer.render_commits({test_commit}, 'comfortable', width)
  for i, line in ipairs(lines) do
    local clean = ansi.strip_ansi(line)
    print("Line " .. i .. " (" .. vim.fn.strdisplaywidth(clean) .. "): " .. clean)
    
    -- Check for empty indicator
    if line:find('\27%[38;5;2m%(empty%)') then
      print("  ✓ Green (empty) indicator found!")
    end
  end
end