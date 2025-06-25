-- Debug symbol extraction
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local commands = require('jj-nvim.jj.commands')

print("=== Debug Symbol and Graph Prefix ===")

-- Test line processing
local test_lines = {
  "○  kuuruowz teernisse@visiostack.com 2025-06-25 17:05:04 ad82c980",
  "│ ○  uvqvrlnl teernisse@visiostack.com 2025-06-25 17:05:04 9ec7c376",
  "@  current teernisse@visiostack.com 2025-06-25 17:05:04 12345678"
}

for i, line in ipairs(test_lines) do
  print(string.format("\nLine %d: %s", i, line))
  
  -- Check symbols
  local has_at = line:find("@")
  local has_circle = line:find("○")  
  local has_diamond = line:find("◆")
  local has_cross = line:find("×")
  
  print(string.format("  has_at=%s has_circle=%s has_diamond=%s has_cross=%s", 
                      tostring(has_at), tostring(has_circle), tostring(has_diamond), tostring(has_cross)))
  
  local symbol = has_at and "@" or has_circle and "○" or has_diamond and "◆" or "×"
  local symbol_pos = has_at and line:find("@") or 
                    has_circle and line:find("○") or 
                    has_diamond and line:find("◆") or 
                    line:find("×")
  
  local graph_prefix = line:sub(1, symbol_pos - 1)
  
  print(string.format("  symbol='%s' symbol_pos=%d graph_prefix='%s'", symbol, symbol_pos, graph_prefix))
end