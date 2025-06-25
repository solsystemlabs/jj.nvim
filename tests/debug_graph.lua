-- Debug graph prefix analysis
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('jj-nvim.core.parser')

print("=== Debug Graph Prefixes ===")

local commits, err = parser.parse_all_commits_with_separate_graph({limit = 5})
if err then
  print("Error: " .. err)
  return
end

for i, commit in ipairs(commits) do
  local prefix = commit.graph_prefix or ""
  print(string.format("Commit %d:", i))
  print(string.format("  prefix: '%s' (length: %d)", prefix, #prefix))
  print(string.format("  symbol: '%s'", commit.symbol or ""))
  
  -- Show character-by-character breakdown
  if #prefix > 0 then
    print("  characters:")
    for j = 1, #prefix do
      local char = prefix:sub(j, j)
      local byte = string.byte(char)
      print(string.format("    %d: '%s' (byte: %d)", j, char, byte))
    end
  end
  
  -- Show additional_lines
  if commit.additional_lines and #commit.additional_lines > 0 then
    print("  additional_lines:")
    for j, line in ipairs(commit.additional_lines) do
      print(string.format("    %d: prefix='%s' content='%s'", j, line.graph_prefix or "", line.content or ""))
    end
  end
  
  print()
end