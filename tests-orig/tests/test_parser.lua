#!/usr/bin/env lua

-- Simple test script to validate our parsing approach
local function execute_jj(args)
  -- Properly escape arguments for shell
  local escaped_args = {}
  for _, arg in ipairs(args) do
    if arg:find("[%s%$%(%)]") then
      table.insert(escaped_args, "'" .. arg .. "'")
    else
      table.insert(escaped_args, arg)
    end
  end
  local cmd = "jj " .. table.concat(escaped_args, " ")
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

-- Test the two-command approach
local function test_separate_parsing()
  print("=== Testing Separate Graph + Data Parsing ===")
  
  -- Get graph structure
  local graph_output = execute_jj({
    'log', '-T', '""', '--limit', '5'
  })
  
  -- Get template data (use simpler template to avoid shell issues)
  local template_output = execute_jj({
    'log', 
    '--template', '"commit_" ++ change_id.short(8) ++ "\\n"',
    '--no-graph', 
    '--limit', '5'
  })
  
  print("Graph output:")
  print(graph_output)
  print("\nTemplate output:")
  print(template_output)
  
  -- Parse graph lines
  local graph_lines = {}
  for line in graph_output:gmatch("[^\r\n]+") do
    if line ~= "" then
      table.insert(graph_lines, line)
    end
  end
  
  -- Parse template lines
  local template_lines = {}
  for line in template_output:gmatch("[^\r\n]+") do
    if line ~= "" then
      table.insert(template_lines, line)
    end
  end
  
  print("\nParsed graph lines:", #graph_lines)
  print("Parsed template lines:", #template_lines)
  
  -- Identify commit vs connector lines
  local commit_count = 0
  local connector_count = 0
  
  for i, line in ipairs(graph_lines) do
    -- Check for node symbols more carefully
    local has_at = line:find("@")
    local has_circle = line:find("○")  
    local has_diamond = line:find("◆")
    local has_cross = line:find("×")
    local has_symbol = has_at or has_circle or has_diamond or has_cross
    
    if has_symbol then
      commit_count = commit_count + 1
      local symbol = has_at and "@" or has_circle and "○" or has_diamond and "◆" or "×"
      print(string.format("Line %d: COMMIT [%s] - %s", i, symbol, line))
    else
      connector_count = connector_count + 1
      print(string.format("Line %d: CONNECTOR - %s", i, line))
    end
  end
  
  print(string.format("\nSummary: %d commits, %d connectors, %d template lines", 
                      commit_count, connector_count, #template_lines))
  
  if commit_count == #template_lines then
    print("✓ SUCCESS: Commit count matches template lines!")
  else
    print("✗ ERROR: Mismatch between commits and template lines")
  end
end

test_separate_parsing()