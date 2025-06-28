#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Debug color extraction
local commands = require('jj-nvim.jj.commands')
local ansi = require('jj-nvim.utils.ansi')

print("=== Debug Color Extraction ===")

-- Get the actual colored log output
local colored_output, err = commands.execute({'log', '--limit', '2', '--no-graph', '--color=always'}, { silent = true })

if not colored_output then
  print("ERROR: Failed to get colored output: " .. (err or "unknown"))
  os.exit(1)
end

print("Raw colored output:")
print(colored_output)
print("\nEscaped view (showing ANSI codes):")
print(colored_output:gsub('\27', '\\27'))

print("\nCleaned output:")
print(ansi.strip_ansi(colored_output))

-- Let's test the field extraction on a single line
local lines = vim.split(colored_output, '\n', { plain = true })
local first_line = lines[1]

if first_line and first_line:find("%S") then
  print("\nFirst line (colored): " .. first_line:gsub('\27', '\\27'))
  print("First line (clean): " .. ansi.strip_ansi(first_line))
  
  -- Try to find commit ID in the line
  local clean_line = ansi.strip_ansi(first_line)
  local commit_id_pattern = "[a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9]"
  local commit_id = clean_line:match(commit_id_pattern)
  
  if commit_id then
    print("Found commit ID: " .. commit_id)
    
    -- Try to find its position and extract color
    local start_pos, end_pos = clean_line:find(commit_id, 1, true)
    if start_pos then
      print("Commit ID position: " .. start_pos .. " to " .. end_pos)
      
      -- Manual color extraction test
      local pos = 1
      local colored_pos = 1
      local target_start = nil
      
      while colored_pos <= #first_line do
        local esc_start, esc_end = first_line:find('\27%[[%d;]*m', colored_pos)
        
        if esc_start and esc_start == colored_pos then
          -- Skip ANSI code
          colored_pos = esc_end + 1
        else
          if pos == start_pos then
            target_start = colored_pos
            break
          end
          pos = pos + 1
          colored_pos = colored_pos + 1
        end
      end
      
      if target_start then
        print("Found target position in colored text: " .. target_start)
        local segment = first_line:sub(target_start, target_start + #commit_id + 20) -- Get a bit extra
        print("Segment: " .. segment:gsub('\27', '\\27'))
        
        local opening_codes = ansi.get_opening_color_codes(segment)
        print("Opening codes: '" .. opening_codes:gsub('\27', '\\27') .. "'")
      end
    end
  else
    print("No commit ID found in clean line")
  end
end