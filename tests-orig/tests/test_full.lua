-- Test the full integration
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')

print("=== Testing Full Integration ===")

local commits, err = parser.parse_all_commits_with_separate_graph({limit = 5})

if err then
  print("Parser Error: " .. err)
  return
end

print("✓ Parser Success: Found " .. #commits .. " commits")

-- Test renderer
local rendered_lines = renderer.render_commits(commits, 'comfortable')
print("✓ Renderer Success: Generated " .. #rendered_lines .. " lines")

-- Check line tracking
for i, commit in ipairs(commits) do
  print(string.format("Commit %d: %s lines %d-%d (header: %d)", 
                      i, commit.short_change_id, 
                      commit.line_start or 0, commit.line_end or 0, 
                      commit.header_line or 0))
end

-- Test commit lookup by line
local test_line = 3
local found_commit = renderer.get_commit_at_line(commits, test_line)
if found_commit then
  print(string.format("✓ Navigation: Line %d belongs to commit %s", test_line, found_commit.short_change_id))
else
  print("✗ Navigation: Could not find commit for line " .. test_line)
end