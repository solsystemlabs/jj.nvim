#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Debug empty indicator insertion in detail
local parser = require('jj-nvim.core.parser')
local ansi = require('jj-nvim.utils.ansi')

print("=== Detailed Debug ===")

-- Get commits
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 1 })
if err or not commits or #commits == 0 then
  print("ERROR: Failed to get commits")
  os.exit(1)
end

-- Find first real commit and mark as empty
local commit = nil
for _, entry in ipairs(commits) do
  if entry.type ~= "elided" and entry.type ~= "connector" then
    commit = entry
    commit.empty = true  -- Force it to be empty for testing
    break
  end
end

if not commit then
  print("ERROR: No commit found")
  os.exit(1)
end

print("Testing with commit: " .. (commit.short_commit_id or "unknown"))
print("Empty status: " .. (commit.empty and "yes" or "no"))

-- Check description methods
print("get_description_text_only(): '" .. commit:get_description_text_only() .. "'")
print("has_real_description(): " .. (commit:has_real_description() and "yes" or "no"))
print("is_current(): " .. (commit:is_current() and "yes" or "no"))

-- Test direct rendering of a single commit
local config = require('jj-nvim.config')
local renderer = require('jj-nvim.core.renderer')

print("\n=== Testing single commit rendering ===")

-- Set comfortable mode
local mode_config = {
  show_description = true,
  show_bookmarks = true,
  single_line = false,
}

-- Manually trace through the rendering logic
local is_current = commit:is_current()
print("is_current in renderer: " .. (is_current and "yes" or "no"))

-- Check if description should be added
local should_show_desc = mode_config.show_description and not mode_config.single_line and not commit.root
print("should_show_desc: " .. (should_show_desc and "yes" or "no"))

if should_show_desc then
  local desc_text = commit:get_description_text_only()
  print("desc_text: '" .. desc_text .. "'")
  
  if desc_text and desc_text ~= "" then
    print("Description will be added to line_parts")
    
    local desc_color
    if commit:has_real_description() then
      desc_color = is_current and "bold_white" or "white"
    else
      desc_color = is_current and "bold_yellow" or "yellow"
    end
    
    print("desc_color: " .. desc_color)
  end
else
  print("Description will NOT be added")
end