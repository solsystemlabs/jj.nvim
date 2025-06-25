-- Test the commit ID matching fix
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')

print("=== Testing Commit ID Matching Fix ===")

-- Test the new parser
local commits, err = parser.parse_all_commits_with_separate_graph({limit = 8})
if err then
  print("Error: " .. err)
  return
end

print("Found " .. #commits .. " commits")

-- Check the ordering by showing change IDs
print("\nCommit order from parser:")
for i, commit in ipairs(commits) do
  print(string.format("%d: %s (commit: %s) prefix: '%s' symbol: '%s'", 
                      i, commit.short_change_id, commit.short_commit_id, 
                      commit.graph_prefix or "", commit.symbol or ""))
end

-- Compare with terminal jj log
print("\nExpected order from terminal jj log:")
print("1: kuuruowz (commit: 7f1dc47c)")
print("2: sxmmqrko (commit: ca8772b9)")  
print("3: uvqvrlnl (commit: 686e916b)")
print("4: lokspvzr (commit: 8bb515c3)")
print("5: vtxznotm (commit: c8db7808)")

-- Test a few lines of rendered output
print("\nFirst few rendered lines:")
local rendered_lines = renderer.render_commits(commits, 'comfortable')
for i = 1, math.min(10, #rendered_lines) do
  local clean_line = rendered_lines[i]:gsub('\27%[[%d;]*m', '') -- Remove ANSI
  print(string.format("%2d: %s", i, clean_line))
end