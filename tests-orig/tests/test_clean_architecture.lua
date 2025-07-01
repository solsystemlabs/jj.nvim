-- Test the clean architecture approach
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local commands = require('jj-nvim.jj.commands')

print("=== Testing Clean Architecture Approach ===")

-- Test the new clean graph command
local graph_output, _ = commands.execute({
  'log', '--template', 'commit_id.short(8)', '--no-pager', '--limit', '8'
}, { silent = true })

print("=== CLEAN GRAPH OUTPUT ===")
print(graph_output)

print("\n=== PARSING TEST ===")
local lines = vim.split(graph_output, '\n', { plain = true })
for i, line in ipairs(lines) do
  if line:match("^%s*$") then
    print(string.format("Line %d: EMPTY", i))
  else
    -- Check for symbols
    local has_at = line:find("@")
    local has_circle = line:find("○")  
    local has_diamond = line:find("◆")
    local has_cross = line:find("×")
    local has_node_symbol = has_at or has_circle or has_diamond or has_cross
    
    if has_node_symbol then
      -- Find first symbol
      local symbol_positions = {}
      if has_at then table.insert(symbol_positions, {pos = line:find("@"), symbol = "@"}) end
      if has_circle then table.insert(symbol_positions, {pos = line:find("○"), symbol = "○"}) end  
      if has_diamond then table.insert(symbol_positions, {pos = line:find("◆"), symbol = "◆"}) end
      if has_cross then table.insert(symbol_positions, {pos = line:find("×"), symbol = "×"}) end
      
      table.sort(symbol_positions, function(a, b) return a.pos < b.pos end)
      local symbol = symbol_positions[1].symbol
      local symbol_pos = symbol_positions[1].pos
      
      local commit_id = line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])")
      local graph_prefix = line:sub(1, symbol_pos - 1)
      
      print(string.format("Line %d: COMMIT symbol='%s' prefix='%s' id='%s'", 
                          i, symbol, graph_prefix, commit_id or "nil"))
    else
      print(string.format("Line %d: CONNECTOR - %s", i, line))
    end
  end
end