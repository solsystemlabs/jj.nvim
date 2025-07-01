-- Test the hybrid fix
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('jj-nvim.core.parser')

print("=== Testing Hybrid Fix ===")

local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 6 })

if err then
  print("Error: " .. err)
  return
end

print(string.format("Found %d commits", #commits))

for i, commit in ipairs(commits) do
  print(string.format("\nCommit %d:", i))
  print(string.format("  ID: %s", commit.short_commit_id))
  print(string.format("  Symbol: %s", commit.symbol))
  print(string.format("  Graph prefix: '%s'", commit.graph_prefix))
  print(string.format("  Description: %s", commit:get_short_description()))
  print(string.format("  Additional lines: %d", #(commit.additional_lines or {})))
  
  if commit.additional_lines then
    for j, line in ipairs(commit.additional_lines) do
      print(string.format("    Line %d: '%s' + '%s'", j, line.graph_prefix, line.content))
    end
  end
end