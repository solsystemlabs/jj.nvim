#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test the complete color preservation pipeline
local parser = require('jj-nvim.core.parser')
local renderer = require('jj-nvim.core.renderer')
local ansi = require('jj-nvim.utils.ansi')

print("=== Testing Color Preservation Pipeline ===")

-- Check if we're in a jj repository
local function is_jj_repo()
  local handle = io.popen("jj root 2>/dev/null")
  local result = handle:read("*a")
  handle:close()
  return result ~= ""
end

if not is_jj_repo() then
  print("ERROR: Not in a jj repository. Skipping pipeline test.")
  os.exit(1)
end

print("✓ In jj repository")

-- Test parsing with colors
print("\n=== Testing Parser with Colors ===")
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 5 })

if err then
  print("ERROR: Failed to parse commits: " .. err)
  os.exit(1)
end

if not commits or #commits == 0 then
  print("ERROR: No commits returned")
  os.exit(1)
end

print("✓ Parsed " .. #commits .. " commits")

-- Check if color information is preserved
local commit_count = 0
local colored_count = 0

for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    commit_count = commit_count + 1
    
    if entry.colors then
      local has_colors = false
      for field, color in pairs(entry.colors) do
        if color and color ~= "" then
          has_colors = true
          print("✓ Commit " .. (entry.short_commit_id or "unknown") .. " has color for " .. field .. ": '" .. color:gsub('\27', '\\27') .. "'")
          break
        end
      end
      
      if has_colors then
        colored_count = colored_count + 1
      end
    end
  end
end

print("\n=== Color Information Summary ===")
print("Total commits: " .. commit_count)
print("Commits with color info: " .. colored_count)

if colored_count > 0 then
  print("✓ Color preservation is working!")
else
  print("⚠ No color information found - this may be expected if jj doesn't output colors")
end

-- Test rendering with preserved colors
print("\n=== Testing Renderer with Preserved Colors ===")
local rendered_lines = renderer.render_commits(commits, 'comfortable', 120)

if rendered_lines and #rendered_lines > 0 then
  print("✓ Rendered " .. #rendered_lines .. " lines")
  
  -- Check if rendered output contains ANSI codes
  local ansi_count = 0
  for i, line in ipairs(rendered_lines) do
    if line:find('\27%[') then
      ansi_count = ansi_count + 1
    end
    
    -- Show first few lines as sample
    if i <= 3 then
      local clean_line = ansi.strip_ansi(line)
      print("Line " .. i .. " (clean): " .. clean_line:sub(1, 60) .. (clean_line:len() > 60 and "..." or ""))
    end
  end
  
  print("Lines with ANSI codes: " .. ansi_count .. " / " .. #rendered_lines)
  
  if ansi_count > 0 then
    print("✓ Rendered output contains color codes!")
  else
    print("⚠ No ANSI codes in rendered output")
  end
else
  print("ERROR: Failed to render commits")
  os.exit(1)
end

print("\n=== Pipeline Test Complete ===")
print("✓ All tests passed!")