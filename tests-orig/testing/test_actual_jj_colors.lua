#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

local commands = require('jj-nvim.jj.commands')
local ansi = require('jj-nvim.utils.ansi')

print("=== Compare Actual JJ Colors ===")

-- Get actual jj default output
local actual_output, err = commands.execute({'log', '--limit', '1', '--color=always'}, { silent = true })
if not actual_output then
  print("ERROR: " .. (err or "unknown"))
  os.exit(1)
end

local actual_line = vim.split(actual_output, '\n')[1]
print("Actual jj output:")
print(actual_line:gsub('\27', '\\27'))
print("Clean: " .. ansi.strip_ansi(actual_line))

-- Get our template output  
local template_output, err2 = commands.execute({'log', '--limit', '1', '--template', '"CHID_START" ++ change_id.short(8) ++ "CHID_END CID_START" ++ commit_id.short(8) ++ "CID_END"', '--no-graph', '--color=always'}, { silent = true })
if template_output then
  print("\nOur template output:")
  print(template_output:gsub('\27', '\\27'))
  print("Clean: " .. ansi.strip_ansi(template_output))
end

-- Extract specific colors from actual output
local clean = ansi.strip_ansi(actual_line)
print("\nAnalyzing actual colors:")

-- Find change ID in actual output (first 8-char hex after @)
local change_id = clean:match("@%s+([a-f0-9]+)")
if change_id then
  print("Change ID found: " .. change_id)
  
  -- Find where this appears in the colored output
  local pos = actual_line:find(change_id, 1, true)
  if pos then
    print("Position: " .. pos)
    -- Get the segment around this position
    local before = actual_line:sub(math.max(1, pos-20), pos-1)
    local segment = actual_line:sub(pos, pos + #change_id + 10)
    print("Before: " .. before:gsub('\27', '\\27'))
    print("Segment: " .. segment:gsub('\27', '\\27'))
  end
end