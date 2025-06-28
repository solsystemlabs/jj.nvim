#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Debug template output
local commands = require('jj-nvim.jj.commands')
local ansi = require('jj-nvim.utils.ansi')

print("=== Debug Template Output ===")

-- Our colored template
local COLORED_TEMPLATE = [["CHID_START" ++ change_id.short(8) ++ "CHID_END \x1F CID_START" ++ commit_id.short(8) ++ "CID_END \x1F AUTH_START" ++ author.email() ++ "AUTH_END \x1F TIME_START" ++ author.timestamp() ++ "TIME_END \x1F DESC_START" ++ description.first_line() ++ "DESC_END \x1F BOOK_START" ++ bookmarks.join(",") ++ "BOOK_END \x1F" ++ if(current_working_copy, "true", "false") ++ "\x1F" ++ if(empty, "true", "false") ++ "\x1F" ++ if(mine, "true", "false") ++ "\x1F" ++ if(root, "true", "false") ++ "\x1F" ++ if(conflict, "true", "false") ++ "\x1F" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\x1E\n"]]

print("Template: " .. COLORED_TEMPLATE)

-- Get colored output with our template
local colored_output, err = commands.execute({'log', '--limit', '2', '--template', COLORED_TEMPLATE, '--no-graph', '--color=always'}, { silent = true })

if not colored_output then
  print("ERROR: " .. (err or "unknown"))
  os.exit(1)
end

print("\nColored output:")
print(colored_output:gsub('\27', '\\27'))

-- Test field extraction
local FIELD_SEP = "\x1F"
local RECORD_SEP = "\x1E"

local commit_blocks = vim.split(colored_output, RECORD_SEP, { plain = true })
print("\nFound " .. #commit_blocks .. " commit blocks")

if #commit_blocks > 0 then
  local block = commit_blocks[1]:match("^%s*(.-)%s*$")
  print("First block: " .. block:gsub('\27', '\\27'))
  
  local parts = vim.split(block, FIELD_SEP, { plain = true })
  print("Found " .. #parts .. " parts")
  
  for i, part in ipairs(parts) do
    print("Part " .. i .. ": " .. part:gsub('\27', '\\27'))
    
    -- Test field extraction
    if i == 1 then -- Change ID field
      local color, text = ansi.extract_field_colors(part, "CHID_START", "CHID_END")
      print("  Change ID color: '" .. color:gsub('\27', '\\27') .. "'")
      print("  Change ID text: '" .. text .. "'")
    elseif i == 2 then -- Commit ID field
      local color, text = ansi.extract_field_colors(part, "CID_START", "CID_END")
      print("  Commit ID color: '" .. color:gsub('\27', '\\27') .. "'")
      print("  Commit ID text: '" .. text .. "'")
    elseif i == 3 then -- Author field
      local color, text = ansi.extract_field_colors(part, "AUTH_START", "AUTH_END")
      print("  Author color: '" .. color:gsub('\27', '\\27') .. "'")
      print("  Author text: '" .. text .. "'")
    end
  end
end