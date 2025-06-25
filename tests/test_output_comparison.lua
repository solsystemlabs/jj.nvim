-- Test to compare our plugin's rendered output with actual jj log output
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local commands = require('jj-nvim.jj.commands')
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== JJ-NVIM OUTPUT COMPARISON TEST ===")

-- Get actual jj log output (reference)
local jj_output, jj_err = commands.execute({'log', '--no-pager', '--limit', '10'}, { silent = true })
if not jj_output then
  print("ERROR: Failed to get jj log output: " .. (jj_err or "unknown error"))
  return
end

print("=== ACTUAL JJ LOG OUTPUT ===")
print(jj_output)

-- Get our plugin's output
local commits, parse_err = parser.parse_commits_with_separate_graph(nil, { limit = 10 })
if parse_err then
  print("ERROR: Failed to parse commits: " .. parse_err)
  return
end

print(string.format("\n=== PLUGIN PARSED %d COMMITS ===", #commits))

-- Render with our plugin 
local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable')

-- Extract clean text from highlighted lines
local plugin_lines = {}
for _, line_data in ipairs(highlighted_lines) do
  table.insert(plugin_lines, line_data.text)
end

local plugin_output = table.concat(plugin_lines, '\n')
print("=== PLUGIN RENDERED OUTPUT ===")
print(plugin_output)

-- Compare line by line
print("\n=== LINE-BY-LINE COMPARISON ===")
local jj_lines = vim.split(jj_output, '\n', { plain = true })
local plugin_lines_array = vim.split(plugin_output, '\n', { plain = true })

local max_lines = math.max(#jj_lines, #plugin_lines_array)

for i = 1, max_lines do
  local jj_line = jj_lines[i] or ""
  local plugin_line = plugin_lines_array[i] or ""
  
  -- Strip ANSI codes from jj output for comparison
  local jj_clean = ansi.strip_ansi(jj_line)
  
  if jj_clean == plugin_line then
    print(string.format("Line %2d: ✓ MATCH", i))
  else
    print(string.format("Line %2d: ✗ DIFF", i))
    print(string.format("  JJ    : '%s'", jj_clean))
    print(string.format("  Plugin: '%s'", plugin_line))
    
    -- Show character-by-character diff for debugging
    if #jj_clean ~= #plugin_line then
      print(string.format("  Length: JJ=%d, Plugin=%d", #jj_clean, #plugin_line))
    end
    
    -- Show first difference position
    for j = 1, math.max(#jj_clean, #plugin_line) do
      local jj_char = jj_clean:sub(j, j)
      local plugin_char = plugin_line:sub(j, j)
      if jj_char ~= plugin_char then
        print(string.format("  First diff at pos %d: JJ='%s'(%d) Plugin='%s'(%d)", 
                           j, jj_char, string.byte(jj_char or ""), 
                           plugin_char, string.byte(plugin_char or "")))
        break
      end
    end
  end
end

print("\n=== SUMMARY ===")
local matching_lines = 0
for i = 1, math.min(#jj_lines, #plugin_lines_array) do
  local jj_clean = ansi.strip_ansi(jj_lines[i] or "")
  local plugin_line = plugin_lines_array[i] or ""
  if jj_clean == plugin_line then
    matching_lines = matching_lines + 1
  end
end

print(string.format("Matching lines: %d/%d", matching_lines, max_lines))
print(string.format("Match rate: %.1f%%", (matching_lines / max_lines) * 100))

-- Also test our parser's raw graph structure
print("\n=== DETAILED COMMIT ANALYSIS ===")
for i, commit in ipairs(commits) do
  if i > 5 then break end -- Only show first 5 commits
  
  print(string.format("\nCommit %d: %s", i, commit.short_commit_id))
  print(string.format("  Graph prefix: '%s'", commit.graph_prefix or ""))
  print(string.format("  Symbol: '%s'", commit.symbol or ""))
  print(string.format("  Graph suffix: '%s'", commit.graph_suffix or ""))
  print(string.format("  Description: '%s'", commit:get_short_description()))
  print(string.format("  Additional lines: %d", #(commit.additional_lines or {})))
  
  if commit.additional_lines then
    for j, line in ipairs(commit.additional_lines) do
      if j > 3 then break end -- Only show first 3 additional lines
      print(string.format("    Line %d: '%s' + '%s'", j, line.graph_prefix, line.content))
    end
  end
end