-- Test graph indentation logic
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')

print("=== Testing Graph Indentation ===")

local commits, err = parser.parse_all_commits_with_separate_graph({limit = 5})
if err then
  print("Error: " .. err)
  return
end

print("Found " .. #commits .. " commits")

-- Show graph prefixes for each commit
for i, commit in ipairs(commits) do
  print(string.format("Commit %d: prefix='%s' symbol='%s'", 
                      i, commit.graph_prefix or "", commit.symbol or ""))
end

-- Test rendering to see indentation
local rendered_lines = renderer.render_commits(commits, 'comfortable')

print("\n=== Rendered Output ===")
for i, line in ipairs(rendered_lines) do
  print(string.format("%2d: %s", i, line))
end

-- Look specifically for lines that should have indentation
print("\n=== Indentation Analysis ===")
for i, line in ipairs(rendered_lines) do
  local stripped = line:gsub('\27%[[%d;]*m', '') -- Remove ANSI codes
  if stripped:match("^│") then
    local prefix = stripped:match("^(│*)")
    print(string.format("Line %d: %d graph chars - %s", i, #prefix, stripped:sub(1, 50)))
  end
end