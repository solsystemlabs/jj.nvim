-- Detailed validation test for jj-nvim parsing and rendering
-- Usage: :luafile test_detailed_validation.lua

local function run_detailed_validation()
  local commands = require('jj-nvim.jj.commands')
  local parser = require('jj-nvim.core.parser')
  local renderer = require('jj-nvim.core.renderer')
  local ansi = require('jj-nvim.utils.ansi')

  print("=== DETAILED JJ-NVIM VALIDATION TEST ===")

  -- Test 1: Basic parsing functionality
  print("\n--- Test 1: Basic Parsing ---")
  local commits, parse_err = parser.parse_commits_with_separate_graph(nil, { limit = 6 })
  if parse_err then
    print("❌ FAIL: Parsing failed: " .. parse_err)
    return false
  end
  print(string.format("✓ PASS: Parsed %d commits successfully", #commits))

  -- Test 2: Commit structure validation
  print("\n--- Test 2: Commit Structure Validation ---")
  local structure_issues = 0
  
  for i, commit in ipairs(commits) do
    -- Check required fields
    if not commit.short_commit_id or commit.short_commit_id == "" then
      print(string.format("❌ Commit %d: Missing short_commit_id", i))
      structure_issues = structure_issues + 1
    end
    
    if not commit.symbol or commit.symbol == "" then
      print(string.format("❌ Commit %d: Missing symbol", i))
      structure_issues = structure_issues + 1
    end
    
    -- Check graph structure
    if commit.graph_prefix == nil then
      print(string.format("❌ Commit %d: graph_prefix is nil", i))
      structure_issues = structure_issues + 1
    end
    
    if commit.graph_suffix == nil then
      print(string.format("❌ Commit %d: graph_suffix is nil", i))
      structure_issues = structure_issues + 1
    end
    
    -- Validate additional_lines structure
    if commit.additional_lines then
      for j, line in ipairs(commit.additional_lines) do
        if not line.graph_prefix or not line.content then
          print(string.format("❌ Commit %d, line %d: Invalid additional line structure", i, j))
          structure_issues = structure_issues + 1
        end
      end
    end
  end
  
  if structure_issues == 0 then
    print("✓ PASS: All commit structures are valid")
  else
    print(string.format("❌ FAIL: Found %d structure issues", structure_issues))
  end

  -- Test 3: Rendering functionality
  print("\n--- Test 3: Rendering Functionality ---")
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable')
  
  if not highlighted_lines or #highlighted_lines == 0 then
    print("❌ FAIL: Rendering produced no output")
    return false
  end
  
  print(string.format("✓ PASS: Rendered %d lines", #highlighted_lines))

  -- Test 4: Output format validation
  print("\n--- Test 4: Output Format Validation ---")
  local format_issues = 0
  
  for i, line_data in ipairs(highlighted_lines) do
    if not line_data.text then
      print(string.format("❌ Line %d: Missing text field", i))
      format_issues = format_issues + 1
    end
    
    if not line_data.segments then
      print(string.format("❌ Line %d: Missing segments field", i))
      format_issues = format_issues + 1
    end
  end
  
  if format_issues == 0 then
    print("✓ PASS: All rendered lines have correct format")
  else
    print(string.format("❌ FAIL: Found %d format issues", format_issues))
  end

  -- Test 5: Comparison with jj log output
  print("\n--- Test 5: Comparison with JJ Log ---")
  local jj_output, jj_err = commands.execute({'log', '--no-pager', '--limit', '6'}, { silent = true })
  if not jj_output then
    print("❌ FAIL: Could not get jj log output: " .. (jj_err or "unknown"))
    return false
  end

  -- Extract clean text from highlighted lines
  local plugin_lines = {}
  for _, line_data in ipairs(highlighted_lines) do
    table.insert(plugin_lines, line_data.text)
  end
  
  local jj_lines = vim.split(jj_output, '\n', { plain = true })
  
  -- Remove empty lines from both for fair comparison
  local function remove_empty_lines(lines)
    local result = {}
    for _, line in ipairs(lines) do
      if line:match("%S") then -- Has non-whitespace characters
        table.insert(result, line)
      end
    end
    return result
  end
  
  local jj_clean_lines = remove_empty_lines(jj_lines)
  local plugin_clean_lines = remove_empty_lines(plugin_lines)
  
  local comparison_issues = 0
  local max_lines = math.max(#jj_clean_lines, #plugin_clean_lines)
  
  for i = 1, max_lines do
    local jj_line = jj_clean_lines[i]
    local plugin_line = plugin_clean_lines[i]
    
    if not jj_line and plugin_line then
      print(string.format("❌ Line %d: Plugin has extra line: '%s'", i, plugin_line))
      comparison_issues = comparison_issues + 1
    elseif jj_line and not plugin_line then
      print(string.format("❌ Line %d: Plugin missing line: '%s'", i, ansi.strip_ansi(jj_line)))
      comparison_issues = comparison_issues + 1
    elseif jj_line and plugin_line then
      local jj_clean = ansi.strip_ansi(jj_line)
      if jj_clean ~= plugin_line then
        print(string.format("❌ Line %d: Content mismatch", i))
        print(string.format("  Expected: '%s'", jj_clean))
        print(string.format("  Got     : '%s'", plugin_line))
        comparison_issues = comparison_issues + 1
      end
    end
  end
  
  if comparison_issues == 0 then
    print("✓ PASS: Output matches jj log exactly")
  else
    print(string.format("❌ FAIL: Found %d comparison issues", comparison_issues))
  end

  -- Test 6: Graph structure integrity
  print("\n--- Test 6: Graph Structure Integrity ---")
  local graph_issues = 0
  
  for i, commit in ipairs(commits) do
    -- Check that commits have reasonable graph structure
    local full_graph = commit.graph_prefix .. commit.symbol .. (commit.graph_suffix or "")
    
    -- Should contain at least a symbol
    if not full_graph:match("[│├─╮╯╭┤~@○◆×]") then
      print(string.format("❌ Commit %d: No graph symbols found in '%s'", i, full_graph))
      graph_issues = graph_issues + 1
    end
    
    -- Check additional lines have consistent indentation
    if commit.additional_lines then
      for j, line in ipairs(commit.additional_lines) do
        if line.content == "" and line.graph_prefix == "" then
          print(string.format("❌ Commit %d, line %d: Empty additional line", i, j))
          graph_issues = graph_issues + 1
        end
      end
    end
  end
  
  if graph_issues == 0 then
    print("✓ PASS: Graph structure is consistent")
  else
    print(string.format("❌ FAIL: Found %d graph structure issues", graph_issues))
  end

  -- Summary
  print("\n=== TEST SUMMARY ===")
  local total_issues = structure_issues + format_issues + comparison_issues + graph_issues
  
  if total_issues == 0 then
    print("🎉 ALL TESTS PASSED! Plugin output matches jj log perfectly.")
    return true
  else
    print(string.format("❌ TESTS FAILED: Found %d total issues across all tests", total_issues))
    print("Check the detailed output above to identify specific problems.")
    return false
  end
end

-- Run the validation
local success = run_detailed_validation()
print(string.format("\nTest result: %s", success and "SUCCESS" or "FAILURE"))