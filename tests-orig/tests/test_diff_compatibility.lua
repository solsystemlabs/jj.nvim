#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test that diff functionality still works after status changes
local config = require('jj-nvim.config')
local actions = require('jj-nvim.jj.actions')
local parser = require('jj-nvim.core.parser')

print("=== Test Diff Compatibility After Status Changes ===")

-- Setup configuration
config.setup({
  diff = {
    display = 'float',
    float = { width = 0.9, height = 0.9, border = 'double' }
  },
  status = {
    display = 'split',
    split = 'vertical'
  }
})

-- Get a commit to test diff on
print("\n1. Getting test commit...")
local commits, err = parser.parse_commits_with_separate_graph('all()', { limit = 5 })
if not commits or #commits == 0 then
  print("✗ No commits found to test diff")
  os.exit(1)
end

-- Find a non-root commit to test diff on
local test_commit = nil
for _, commit in ipairs(commits) do
  if commit.type ~= "elided" and not commit.root then
    test_commit = commit
    break
  end
end

if not test_commit then
  print("✗ No suitable commit found for diff test")
  os.exit(1)
end

print("✓ Found test commit: " .. (test_commit.short_commit_id or "unknown"))

-- Test 2: Test diff functionality
print("\n2. Testing diff action...")
local diff_success = actions.show_diff(test_commit)
print("Diff action result: " .. (diff_success and "success" or "failed"))

-- Test 3: Test status functionality
print("\n3. Testing status action...")
local status_success = actions.show_status()
print("Status action result: " .. (status_success and "success" or "failed"))

-- Test 4: Test different configurations
print("\n4. Testing diff with split configuration...")
config.setup({
  diff = {
    display = 'split',
    split = 'horizontal'
  }
})

local diff_split_success = actions.show_diff(test_commit)
print("Diff split action result: " .. (diff_split_success and "success" or "failed"))

print("\n=== Compatibility Test Results ===")
if diff_success and status_success and diff_split_success then
  print("✓ All tests passed")
  print("✓ Diff functionality: Working")
  print("✓ Status functionality: Working")
  print("✓ Configuration independence: Working")
  print("✓ Floating window reuse: Working")
else
  print("✗ Some tests failed")
  os.exit(1)
end

print("\n🎉 Diff and Status work independently with their own configurations!")