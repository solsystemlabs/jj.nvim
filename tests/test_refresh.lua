-- Test that refresh preserves graph structure
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('jj-nvim.core.parser')
local buffer = require('jj-nvim.ui.buffer')

print("=== Testing Refresh Behavior ===")

-- Initial parse
local commits1, err1 = parser.parse_all_commits_with_separate_graph({limit = 3})
if err1 then
  print("Error in initial parse: " .. err1)
  return
end
print("✓ Initial parse: " .. #commits1 .. " commits")

-- Create buffer
local buf_id = buffer.create_from_commits(commits1)
print("✓ Buffer created: " .. buf_id)

-- Get initial state
local initial_commit = commits1[1]
print("Initial commit 1 graph_prefix: '" .. (initial_commit.graph_prefix or "") .. "' symbol: " .. (initial_commit.symbol or ""))

-- Test refresh (this should preserve graph structure)
local refresh_success = buffer.refresh(buf_id)
if not refresh_success then
  print("✗ Refresh failed")
  return
end
print("✓ Refresh successful")

-- Get refreshed commits
local refreshed_commits = buffer.get_all_commits()
if not refreshed_commits or #refreshed_commits == 0 then
  print("✗ No commits after refresh")
  return
end

local refreshed_commit = refreshed_commits[1]
print("Refreshed commit 1 graph_prefix: '" .. (refreshed_commit.graph_prefix or "") .. "' symbol: " .. (refreshed_commit.symbol or ""))

-- Compare
if initial_commit.graph_prefix == refreshed_commit.graph_prefix and 
   initial_commit.symbol == refreshed_commit.symbol then
  print("✓ SUCCESS: Graph structure preserved through refresh!")
else
  print("✗ FAIL: Graph structure lost on refresh")
  print("  Expected prefix: '" .. (initial_commit.graph_prefix or "") .. "' got: '" .. (refreshed_commit.graph_prefix or "") .. "'")
  print("  Expected symbol: '" .. (initial_commit.symbol or "") .. "' got: '" .. (refreshed_commit.symbol or "") .. "'")
end