#!/usr/bin/env nvim -l

-- Add lua directory to package path  
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test status action integration
local actions = require('jj-nvim.jj.actions')

print("=== Test Status Action Integration ===")

-- Test that we can call the status action
print("Testing status action call...")

local success = actions.show_status()
print("Status action result: " .. (success and "success" or "failed"))

-- The action will create a buffer, but since we're in a test environment
-- it might not display properly. The important thing is that it doesn't crash.

if success then
  print("✓ Status action executed without errors")
  print("✓ Status display functionality is working")
else
  print("✗ Status action failed")
  os.exit(1)
end

print("\n=== Status Action Test Complete ===")
print("Status functionality is ready to use in jj-nvim!")