-- Simple test runner for jj-nvim
-- Usage: lua run_tests.lua

package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Mock vim functions for standalone execution
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
    fn = {
      strchars = function(str)
        -- Simple UTF-8 character count approximation
        local count = 0
        for i = 1, #str do
          local byte = string.byte(str, i)
          if byte < 128 or byte >= 192 then
            count = count + 1
          end
        end
        return count
      end,
      strcharpart = function(str, start, len)
        -- Simple substring approximation
        return str:sub(start + 1, start + len)
      end
    },
    log = {
      levels = {
        INFO = 2,
        WARN = 3,
        ERROR = 4
      }
    },
    notify = function(msg, level)
      local level_name = "INFO"
      if level == 4 then level_name = "ERROR"
      elseif level == 3 then level_name = "WARN" end
      print(string.format("[%s] %s", level_name, msg))
    end
  }
end

local function run_basic_test()
  print("=== BASIC JJ-NVIM TEST ===")
  
  local commands = require('jj-nvim.jj.commands')
  local parser = require('jj-nvim.core.parser')
  
  -- Test 1: Can we execute jj commands?
  print("\n1. Testing jj command execution...")
  local result, err = commands.execute({'log', '--limit', '1', '--no-pager'}, { silent = true })
  if not result then
    print("❌ FAIL: Cannot execute jj commands: " .. (err or "unknown error"))
    return false
  end
  print("✓ PASS: jj command execution works")
  
  -- Test 2: Can we parse commits?
  print("\n2. Testing commit parsing...")
  local commits, parse_err = parser.parse_commits_with_separate_graph(nil, { limit = 3 })
  if parse_err then
    print("❌ FAIL: Commit parsing failed: " .. parse_err)
    return false
  end
  if #commits == 0 then
    print("❌ FAIL: No commits parsed")
    return false
  end
  print(string.format("✓ PASS: Parsed %d commits", #commits))
  
  -- Test 3: Do commits have required structure?
  print("\n3. Testing commit structure...")
  local first_commit = commits[1]
  local required_fields = {'short_commit_id', 'symbol', 'graph_prefix', 'graph_suffix'}
  
  for _, field in ipairs(required_fields) do
    if first_commit[field] == nil then
      print(string.format("❌ FAIL: Missing field '%s' in commit", field))
      return false
    end
  end
  print("✓ PASS: Commit structure is valid")
  
  -- Test 4: Can we render commits?
  print("\n4. Testing commit rendering...")
  local renderer = require('jj-nvim.core.renderer')
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable')
  
  if not highlighted_lines or #highlighted_lines == 0 then
    print("❌ FAIL: Rendering produced no output")
    return false
  end
  print(string.format("✓ PASS: Rendered %d lines", #highlighted_lines))
  
  print("\n🎉 ALL BASIC TESTS PASSED!")
  return true
end

local function show_sample_output()
  print("\n=== SAMPLE OUTPUT ===")
  
  local parser = require('jj-nvim.core.parser')
  local renderer = require('jj-nvim.core.renderer')
  
  local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 5 })
  if err then
    print("Error getting sample output: " .. err)
    return
  end
  
  local highlighted_lines, _ = renderer.render_with_highlights(commits, 'comfortable')
  
  print("Plugin output:")
  for i, line_data in ipairs(highlighted_lines) do
    if i > 10 then break end -- Limit output
    print(string.format("%2d: %s", i, line_data.text))
  end
end

-- Run tests
local success = run_basic_test()

if success then
  show_sample_output()
else
  print("\n❌ Basic tests failed - check error messages above")
end