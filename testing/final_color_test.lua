#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Final comparison test
local commands = require('jj-nvim.jj.commands')
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Final Color Comparison Test ===")

-- Get actual jj output
local actual_output, err = commands.execute({'log', '--limit', '1', '--color=always'}, { silent = true })
if not actual_output then
  print("ERROR: " .. (err or "unknown"))
  os.exit(1)
end

local actual_line = vim.split(actual_output, '\n')[1]
print("Actual jj output:")
print(actual_line:gsub('\27', '\\27'))

-- Get our plugin output
local commits, err2 = parser.parse_commits_with_separate_graph('all()', { limit = 1 })
if err2 or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

local commit = nil
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    commit = entry
    break
  end
end

if not commit then
  print("ERROR: No commit found")
  os.exit(1)
end

local lines = renderer.render_commits({commit}, 'comfortable', 120)
if not lines or #lines == 0 then
  print("ERROR: No lines rendered")
  os.exit(1)
end

local our_line = lines[1]
print("\nOur plugin output:")
print(our_line:gsub('\27', '\\27'))

print("\nComparison:")
print("Actual clean: " .. ansi.strip_ansi(actual_line))
print("Ours clean:   " .. ansi.strip_ansi(our_line))

print("\nColor Analysis:")
-- Extract color segments from both
local function extract_colors(line)
  local segments = {}
  local pos = 1
  while pos <= #line do
    local esc_start, esc_end = line:find('\27%[[%d;]*m', pos)
    if not esc_start then
      break
    end
    local code = line:sub(esc_start, esc_end)
    table.insert(segments, code)
    pos = esc_end + 1
  end
  return segments
end

local actual_colors = extract_colors(actual_line)
local our_colors = extract_colors(our_line)

print("Actual colors: " .. table.concat(actual_colors, " "))
print("Our colors:    " .. table.concat(our_colors, " "))

local matches = 0
local total = math.max(#actual_colors, #our_colors)
for i = 1, math.min(#actual_colors, #our_colors) do
  if actual_colors[i] == our_colors[i] then
    matches = matches + 1
  else
    print("Difference at position " .. i .. ": actual '" .. actual_colors[i] .. "' vs ours '" .. our_colors[i] .. "'")
  end
end

print(string.format("\nColor match: %d/%d (%.1f%%)", matches, total, matches/total*100))