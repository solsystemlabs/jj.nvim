-- Test rebase command construction
local function test_rebase_args()
  print("=== Testing Single Commit Rebase ===")
  local options = {
    branch = "abc123",
    destination = "xyz789"
  }
  
  local cmd_args = { 'rebase' }
  
  -- Add source selection options
  if options.branch then
    table.insert(cmd_args, '-b')
    table.insert(cmd_args, options.branch)
  end
  
  -- Add destination
  if options.destination then
    table.insert(cmd_args, '-d')
    table.insert(cmd_args, options.destination)
  end
  
  print("Branch mode command args:")
  for i, arg in ipairs(cmd_args) do
    print(i .. ": " .. arg)
  end
  
  -- Test with insert-after
  local cmd_args2 = { 'rebase' }
  local options2 = {
    source = "def456",
    insert_after = "ghi789"
  }
  
  if options2.source then
    table.insert(cmd_args2, '-s')
    table.insert(cmd_args2, options2.source)
  end
  
  if options2.insert_after then
    table.insert(cmd_args2, '-A')
    table.insert(cmd_args2, options2.insert_after)
  end
  
  print("\nSource with insert-after:")
  for i, arg in ipairs(cmd_args2) do
    print(i .. ": " .. arg)
  end
  
  print("\n=== Testing Multi-Commit Rebase ===")
  -- Test multi-commit revisions mode
  local cmd_args3 = { 'rebase' }
  local options3 = {
    revisions = {"abc123", "def456", "ghi789"},
    insert_before = "target123"
  }
  
  if options3.revisions then
    table.insert(cmd_args3, '-r')
    for _, revision in ipairs(options3.revisions) do
      table.insert(cmd_args3, revision)
    end
  end
  
  if options3.insert_before then
    table.insert(cmd_args3, '-B')
    table.insert(cmd_args3, options3.insert_before)
  end
  
  print("Multi-commit revisions with insert-before:")
  for i, arg in ipairs(cmd_args3) do
    print(i .. ": " .. arg)
  end
  
  print("\n=== Testing Flags ===")
  -- Test with flags
  local cmd_args4 = { 'rebase' }
  local options4 = {
    branch = "abc123",
    destination = "target456",
    skip_emptied = true,
    keep_divergent = true
  }
  
  if options4.branch then
    table.insert(cmd_args4, '-b')
    table.insert(cmd_args4, options4.branch)
  end
  
  if options4.destination then
    table.insert(cmd_args4, '-d')
    table.insert(cmd_args4, options4.destination)
  end
  
  if options4.skip_emptied then
    table.insert(cmd_args4, '--skip-emptied')
  end
  
  if options4.keep_divergent then
    table.insert(cmd_args4, '--keep-divergent')
  end
  
  print("Branch mode with flags:")
  for i, arg in ipairs(cmd_args4) do
    print(i .. ": " .. arg)
  end
end

test_rebase_args()