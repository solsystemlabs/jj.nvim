-- Test that can be run within Neovim to compare outputs
-- Usage: :luafile test_in_nvim.lua

local function test_output_comparison()
  local commands = require('jj-nvim.jj.commands')
  local parser = require('jj-nvim.core.parser')
  local renderer = require('jj-nvim.core.renderer')
  local ansi = require('jj-nvim.utils.ansi')

  print("=== JJ-NVIM OUTPUT COMPARISON TEST ===")

  -- Get actual jj log output (reference)
  local jj_output, jj_err = commands.execute({'log', '--no-pager', '--limit', '8'}, { silent = true })
  if not jj_output then
    print("ERROR: Failed to get jj log output: " .. (jj_err or "unknown error"))
    return
  end

  -- Get our plugin's output
  local commits, parse_err = parser.parse_commits_with_separate_graph(nil, { limit = 8 })
  if parse_err then
    print("ERROR: Failed to parse commits: " .. parse_err)
    return
  end

  -- Render with our plugin 
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable')

  -- Extract clean text from highlighted lines
  local plugin_lines = {}
  for _, line_data in ipairs(highlighted_lines) do
    table.insert(plugin_lines, line_data.text)
  end

  -- Compare line by line
  print("=== COMPARISON RESULTS ===")
  local jj_lines = vim.split(jj_output, '\n', { plain = true })
  
  local matching_lines = 0
  local total_lines = math.max(#jj_lines, #plugin_lines)
  
  for i = 1, math.min(#jj_lines, #plugin_lines) do
    local jj_line = jj_lines[i] or ""
    local plugin_line = plugin_lines[i] or ""
    
    -- Strip ANSI codes from jj output for comparison
    local jj_clean = ansi.strip_ansi(jj_line)
    
    if jj_clean == plugin_line then
      matching_lines = matching_lines + 1
      print(string.format("Line %2d: ✓", i))
    else
      print(string.format("Line %2d: ✗ DIFF", i))
      print(string.format("  Expected: '%s'", jj_clean))
      print(string.format("  Got     : '%s'", plugin_line))
    end
  end

  -- Report mismatched line counts
  if #jj_lines ~= #plugin_lines then
    print(string.format("Line count mismatch: JJ=%d, Plugin=%d", #jj_lines, #plugin_lines))
  end

  print(string.format("\nSUMMARY: %d/%d lines match (%.1f%%)", 
                     matching_lines, total_lines, (matching_lines / total_lines) * 100))
  
  -- Show first few commits' structure for debugging
  print("\n=== COMMIT STRUCTURE DEBUG ===")
  for i = 1, math.min(3, #commits) do
    local commit = commits[i]
    print(string.format("Commit %d (%s):", i, commit.short_commit_id))
    print(string.format("  prefix='%s' symbol='%s' suffix='%s'", 
                       commit.graph_prefix or "", commit.symbol or "", commit.graph_suffix or ""))
    print(string.format("  additional_lines: %d", #(commit.additional_lines or {})))
  end
  
  return matching_lines == total_lines
end

-- Run the test
local success = test_output_comparison()
if success then
  print("\n🎉 ALL TESTS PASSED!")
else
  print("\n❌ Some tests failed - check output above")
end