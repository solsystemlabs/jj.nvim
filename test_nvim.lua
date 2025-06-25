-- Test the parser in Neovim environment
-- Add current directory to package path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('jj-nvim.core.parser')

local commits, err = parser.parse_all_commits_with_separate_graph({limit = 3})

if err then
  print("Error: " .. err)
else
  print("Success! Found " .. #commits .. " commits")
  for i, commit in ipairs(commits) do
    print(string.format("Commit %d: %s (symbol: %s, prefix: '%s')", 
                        i, commit.short_change_id, commit.symbol, commit.graph_prefix))
    if commit.additional_lines and #commit.additional_lines > 0 then
      print("  Additional lines: " .. #commit.additional_lines)
    end
  end
end