-- Debug the double symbol issue
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local commands = require('jj-nvim.jj.commands')

print("=== DEBUGGING DOUBLE SYMBOLS ===")

-- Test what our graph command produces
local graph_output, err = commands.execute({
  'log', '--template', '"*" ++ commit_id.short(8)', '--limit', '3', '--no-pager'
}, { silent = true })

if not graph_output then
  print("ERROR: " .. (err or "unknown"))
  return
end

print("=== RAW GRAPH OUTPUT ===")
local graph_lines = vim.split(graph_output, '\n', { plain = true })
for i, line in ipairs(graph_lines) do
  if line:match("%S") then -- Only show non-empty lines
    print(string.format("%2d: '%s'", i, line))
    
    if line:find("*", 1, true) then
      local star_pos = line:find("*", 1, true)
      local graph_part = line:sub(1, star_pos - 1)
      local commit_id = line:sub(star_pos + 1):match("^%s*(.-)%s*$")
      
      print(string.format("    SPLIT: graph='%s' commit_id='%s'", graph_part, commit_id))
      
      -- Test symbol detection
      local symbols = {"@", "○", "◆", "×"}
      local symbol = nil
      local symbol_pos = nil
      
      for j = #graph_part, 1, -1 do
        local char = graph_part:sub(j, j)
        for _, sym in ipairs(symbols) do
          if char == sym then
            symbol = sym
            symbol_pos = j
            break
          end
        end
        if symbol then break end
      end
      
      if symbol and symbol_pos then
        local prefix = graph_part:sub(1, symbol_pos - 1)
        local suffix = graph_part:sub(symbol_pos + 1)
        print(string.format("    PARSED: prefix='%s' symbol='%s' suffix='%s'", prefix, symbol, suffix))
        print(string.format("    SHOULD RENDER AS: '%s%s%s'", prefix, symbol, suffix))
      end
    else
      print("    NON-COMMIT LINE")
    end
  end
end

print("\n=== EXPECTED OUTPUT (from regular jj log) ===")
local regular_output, _ = commands.execute({'log', '--limit', '3', '--no-pager'}, { silent = true })
if regular_output then
  local regular_lines = vim.split(regular_output, '\n', { plain = true })
  for i, line in ipairs(regular_lines) do
    if line:match("%S") then
      local clean_line = line:gsub('\27%[[0-9;]*m', '') -- Strip ANSI
      print(string.format("%2d: '%s'", i, clean_line))
    end
  end
end