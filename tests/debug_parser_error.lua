-- Debug the parser error
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Mock vim for testing
if not vim then
  _G.vim = {
    split = function(str, sep, opts)
      local result = {}
      local pattern = string.format("([^%s]+)", sep)
      for match in str:gmatch(pattern) do
        table.insert(result, match)
      end
      return result
    end,
    log = { levels = { ERROR = 4, WARN = 3, INFO = 2 } },
    notify = function(msg, level) print("[NOTIFY] " .. msg) end
  }
end

local parser = require('jj-nvim.core.parser')

print("=== DEBUGGING PARSER ERROR ===")

-- Test the new parsing function
local commits, err = parser.parse_all_commits_with_separate_graph({ limit = 5 })

print(string.format("Result: commits=%s, err=%s", 
                   commits and string.format("table with %d items", #commits) or tostring(commits), 
                   tostring(err)))

if err then
  print("ERROR: " .. err)
elseif not commits then
  print("ERROR: commits is nil but no error returned")
elseif type(commits) ~= 'table' then
  print("ERROR: commits is not a table, type=" .. type(commits))
else
  print(string.format("SUCCESS: Got %d commits", #commits))
  
  -- Show first few commits
  for i = 1, math.min(3, #commits) do
    local commit = commits[i]
    print(string.format("Commit %d:", i))
    print(string.format("  ID: %s", commit.short_commit_id or "nil"))
    print(string.format("  Symbol: %s", commit.symbol or "nil"))
    print(string.format("  Prefix: '%s'", commit.graph_prefix or "nil"))
    print(string.format("  Suffix: '%s'", commit.graph_suffix or "nil"))
  end
end