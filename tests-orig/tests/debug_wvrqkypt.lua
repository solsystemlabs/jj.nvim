-- Debug the wvrqkypt commit parsing specifically
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local commands = require('jj-nvim.jj.commands')
local parser = require('jj-nvim.core.parser')
local ansi = require('jj-nvim.utils.ansi')

print("=== DEBUGGING WVRQKYPT COMMIT ===")

-- Get raw jj log output
local jj_output, err = commands.execute({'log', '--no-pager', '--limit', '8'}, { silent = true })
if not jj_output then
  print("ERROR: " .. (err or "unknown"))
  return
end

print("=== RAW JJ LOG OUTPUT ===")
local jj_lines = vim.split(jj_output, '\n', { plain = true })
for i, line in ipairs(jj_lines) do
  local clean_line = ansi.strip_ansi(line)
  if clean_line:find("wvrqkypt") then
    print(string.format("Line %d (RAW): '%s'", i, line))
    print(string.format("Line %d (CLEAN): '%s'", i, clean_line))
    
    -- Character-by-character analysis
    print("Character analysis:")
    for j = 1, #clean_line do
      local char = clean_line:sub(j, j)
      local byte_val = string.byte(char)
      print(string.format("  pos %d: '%s' (byte: %d)", j, char, byte_val))
      if j > 20 then break end -- Don't spam too much
    end
  end
end

-- Parse with our plugin and find the wvrqkypt commit
local commits, parse_err = parser.parse_commits_with_separate_graph(nil, { limit = 8 })
if parse_err then
  print("Parse error: " .. parse_err)
  return
end

print("\n=== PARSED WVRQKYPT COMMIT ===")
for i, commit in ipairs(commits) do
  if commit.short_change_id and commit.short_change_id:find("wvrqkypt") then
    print(string.format("Found wvrqkypt at commit %d:", i))
    print(string.format("  short_commit_id: '%s'", commit.short_commit_id))
    print(string.format("  graph_prefix: '%s' (len=%d)", commit.graph_prefix or "", #(commit.graph_prefix or "")))
    print(string.format("  symbol: '%s'", commit.symbol or ""))
    print(string.format("  graph_suffix: '%s' (len=%d)", commit.graph_suffix or "", #(commit.graph_suffix or "")))
    
    -- Show what our renderer will produce
    local full_graph = (commit.graph_prefix or "") .. (commit.symbol or "") .. (commit.graph_suffix or "")
    print(string.format("  reconstructed: '%s'", full_graph))
    break
  end
end

-- Let's also manually test our parsing logic on the specific line
print("\n=== MANUAL PARSING TEST ===")
for i, line in ipairs(jj_lines) do
  local clean_line = ansi.strip_ansi(line)
  if clean_line:find("wvrqkypt") then
    print(string.format("Testing line: '%s'", clean_line))
    
    -- Find symbols
    local symbol_positions = {}
    local has_circle = line:find("○")
    if has_circle then 
      table.insert(symbol_positions, {pos = has_circle, symbol = "○"})
      print(string.format("Found ○ at position %d", has_circle))
    end
    
    if #symbol_positions > 0 then
      local symbol = symbol_positions[1].symbol
      local symbol_pos = symbol_positions[1].pos
      local graph_prefix = clean_line:sub(1, symbol_pos - 1)
      
      print(string.format("Symbol: '%s' at pos %d", symbol, symbol_pos))
      print(string.format("Graph prefix: '%s'", graph_prefix))
      
      -- Test our suffix extraction logic
      local after_symbol = clean_line:sub(symbol_pos + 1)
      print(string.format("After symbol: '%s'", after_symbol))
      
      local graph_suffix = ""
      local found_graph_char = false
      
      for j = 1, #after_symbol do
        local char = after_symbol:sub(j, j)
        print(string.format("  char %d: '%s' (byte: %d)", j, char, string.byte(char)))
        
        if char:match("[│├─╮╯╭┤~]") then
          graph_suffix = graph_suffix .. char
          found_graph_char = true
          print(string.format("    -> Added to suffix: '%s'", graph_suffix))
        elseif char == " " then
          if found_graph_char then
            print("    -> Found space after graph char, stopping")
            break
          else
            graph_suffix = graph_suffix .. char
            print(string.format("    -> Added space to suffix: '%s'", graph_suffix))
          end
        else
          print("    -> Hit commit info, stopping")
          break
        end
      end
      
      print(string.format("Final suffix: '%s' (len=%d)", graph_suffix, #graph_suffix))
    end
    break
  end
end