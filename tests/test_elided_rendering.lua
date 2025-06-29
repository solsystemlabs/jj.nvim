#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test elided sections rendering
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Test Elided Sections Rendering ===")

-- Get commits with elided sections
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 15 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find and test elided sections specifically
local found_elided = false
for i, entry in ipairs(commits) do
  if entry.type == "elided" then
    found_elided = true
    print("\nFound elided section at entry " .. i .. ":")
    print("  Type: " .. entry.type)
    print("  Lines:")
    for j, line in ipairs(entry.lines or {}) do
      print("    " .. j .. ": '" .. ansi.strip_ansi(line) .. "'")
    end
  end
end

if not found_elided then
  print("No elided sections found in first 15 entries")
  os.exit(1)
end

-- Test rendering the entries including elided sections
print("\n=== Full Rendering Test ===")
local lines = renderer.render_commits(commits, 'comfortable', 80)

-- Find lines that should contain elided content
local elided_lines = {}
for i, line in ipairs(lines) do
  local clean_line = ansi.strip_ansi(line)
  if clean_line:match("%(elided revisions%)") or clean_line:match("^~") then
    table.insert(elided_lines, { line_num = i, content = clean_line })
  end
end

print("Found " .. #elided_lines .. " elided lines in rendering:")
for _, elided_line in ipairs(elided_lines) do
  print("  Line " .. elided_line.line_num .. ": '" .. elided_line.content .. "'")
end

-- Show a few lines around the first elided section for context
if #elided_lines > 0 then
  local first_elided_line = elided_lines[1].line_num
  local start_line = math.max(1, first_elided_line - 2)
  local end_line = math.min(#lines, first_elided_line + 2)
  
  print("\nContext around first elided section:")
  for i = start_line, end_line do
    local marker = (i == first_elided_line) and " >>> " or "     "
    print(marker .. "Line " .. i .. ": '" .. ansi.strip_ansi(lines[i]) .. "'")
  end
end