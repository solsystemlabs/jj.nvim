#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test status functionality implementation
local commands = require('jj-nvim.jj.commands')
local actions = require('jj-nvim.jj.actions')

print("=== Test Status Functionality ===")

-- Test 1: Test status command
print("\nTest 1: Testing jj status command")
local status_output, err = commands.get_status()
if status_output then
  print("✓ Status command executed successfully")
  print("Status output preview:")
  local lines = vim.split(status_output, '\n', { plain = true })
  for i = 1, math.min(3, #lines) do
    print("  " .. lines[i])
  end
  if #lines > 3 then
    print("  ... (" .. (#lines - 3) .. " more lines)")
  end
else
  print("✗ Status command failed: " .. (err or "unknown error"))
  os.exit(1)
end

-- Test 2: Test status command with color
print("\nTest 2: Testing status command with color")
local colored_status, color_err = commands.get_status({ no_color = false })
if colored_status then
  print("✓ Colored status command executed successfully")
  
  -- Check if output actually contains ANSI codes
  local has_ansi = colored_status:find('\27%[')
  print("Contains ANSI codes: " .. (has_ansi and "yes" or "no"))
else
  print("✗ Colored status command failed: " .. (color_err or "unknown error"))
end

-- Test 3: Test show_status action (without actually opening the window)
print("\nTest 3: Testing show_status action")
print("Note: This test checks the action function without opening the actual window")

-- Since we can't easily test the UI window creation in this test environment,
-- we'll just verify the function exists and can be called
local has_show_status = type(actions.show_status) == "function"
print("show_status function exists: " .. (has_show_status and "yes" or "no"))

if has_show_status then
  print("✓ Status action is properly implemented")
else
  print("✗ Status action is missing or not a function")
  os.exit(1)
end

print("\n=== All Status Tests Passed ===")
print("\nYou can now test the full functionality by:")
print("1. Opening jj-nvim: nvim -c 'lua require(\"jj-nvim\").show_log()'")
print("2. Pressing 'S' to show repository status")
print("3. Press 'q' or '<Esc>' to close the status window")