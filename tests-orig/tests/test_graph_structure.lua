-- Test specifically for graph structure parsing and rendering
-- Usage: :luafile test_graph_structure.lua

local function test_graph_structure()
  local commands = require('jj-nvim.jj.commands')
  local parser = require('jj-nvim.core.parser')
  local renderer = require('jj-nvim.core.renderer')
  local ansi = require('jj-nvim.utils.ansi')

  print("=== GRAPH STRUCTURE TEST ===")

  -- Get raw jj log output to analyze the structure
  local jj_output, err = commands.execute({'log', '--no-pager', '--limit', '8'}, { silent = true })
  if not jj_output then
    print("❌ Failed to get jj log output: " .. (err or "unknown"))
    return false
  end

  print("=== RAW JJ LOG OUTPUT ===")
  local jj_lines = vim.split(jj_output, '\n', { plain = true })
  for i, line in ipairs(jj_lines) do
    if line:match("%S") then -- Only show non-empty lines
      local clean_line = ansi.strip_ansi(line)
      print(string.format("%2d: '%s'", i, clean_line))
    end
  end

  -- Parse with our plugin
  local commits, parse_err = parser.parse_commits_with_separate_graph(nil, { limit = 8 })
  if parse_err then
    print("❌ Parsing failed: " .. parse_err)
    return false
  end

  print(string.format("\n=== PARSED COMMIT STRUCTURE (%d commits) ===", #commits))
  for i, commit in ipairs(commits) do
    print(string.format("Commit %d: %s", i, commit.short_commit_id))
    print(string.format("  prefix: '%s' (len=%d)", commit.graph_prefix or "", #(commit.graph_prefix or "")))
    print(string.format("  symbol: '%s'", commit.symbol or ""))
    print(string.format("  suffix: '%s' (len=%d)", commit.graph_suffix or "", #(commit.graph_suffix or "")))
    print(string.format("  full_graph: '%s%s%s'", commit.graph_prefix or "", commit.symbol or "", commit.graph_suffix or ""))
    print(string.format("  additional_lines: %d", #(commit.additional_lines or {})))
    
    if commit.additional_lines and #commit.additional_lines > 0 then
      for j, line in ipairs(commit.additional_lines) do
        if j <= 2 then -- Show first 2 additional lines
          print(string.format("    line %d: '%s' + '%s'", j, line.graph_prefix, line.content))
        end
      end
    end
    print()
  end

  -- Render and compare
  local highlighted_lines, _ = renderer.render_with_highlights(commits, 'comfortable')
  
  print("=== RENDERED OUTPUT ===")
  for i, line_data in ipairs(highlighted_lines) do
    print(string.format("%2d: '%s'", i, line_data.text))
  end

  -- Line-by-line comparison
  print("\n=== COMPARISON ===")
  local plugin_lines = {}
  for _, line_data in ipairs(highlighted_lines) do
    table.insert(plugin_lines, line_data.text)
  end

  local mismatches = 0
  local jj_clean_lines = {}
  
  -- Clean jj lines for comparison
  for _, line in ipairs(jj_lines) do
    if line:match("%S") then
      table.insert(jj_clean_lines, ansi.strip_ansi(line))
    end
  end

  for i = 1, math.max(#jj_clean_lines, #plugin_lines) do
    local jj_line = jj_clean_lines[i] or ""
    local plugin_line = plugin_lines[i] or ""
    
    if jj_line == plugin_line then
      print(string.format("Line %2d: ✓", i))
    else
      print(string.format("Line %2d: ✗", i))
      print(string.format("  Expected: '%s'", jj_line))
      print(string.format("  Got     : '%s'", plugin_line))
      mismatches = mismatches + 1
      
      -- Character-by-character analysis for first few mismatches
      if mismatches <= 3 then
        print("  Character analysis:")
        local max_len = math.max(#jj_line, #plugin_line)
        for j = 1, max_len do
          local jj_char = jj_line:sub(j, j)
          local plugin_char = plugin_line:sub(j, j)
          if jj_char ~= plugin_char then
            print(string.format("    pos %d: expected '%s'(%d) got '%s'(%d)", 
                               j, jj_char, string.byte(jj_char or ""), 
                               plugin_char, string.byte(plugin_char or "")))
            break
          end
        end
      end
    end
  end

  print(string.format("\n=== RESULTS ==="))
  print(string.format("Total lines compared: %d", math.max(#jj_clean_lines, #plugin_lines)))
  print(string.format("Mismatches: %d", mismatches))
  print(string.format("Match rate: %.1f%%", ((math.max(#jj_clean_lines, #plugin_lines) - mismatches) / math.max(#jj_clean_lines, #plugin_lines)) * 100))

  return mismatches == 0
end

-- Run the test
local success = test_graph_structure()
print(string.format("\nGraph structure test: %s", success and "PASSED" or "FAILED"))