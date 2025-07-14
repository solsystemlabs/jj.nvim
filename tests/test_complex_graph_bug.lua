-- Test to reproduce the complex graph scenario bug
local renderer = require('jj-nvim.core.renderer')
local commit_module = require('jj-nvim.core.commit')

local function test_complex_graph_scenario()
  print("=== Testing Complex Graph Scenario ===")
  
  local commits = {}
  
  -- First commit: the merge commit with complex graph pattern
  table.insert(commits, commit_module.from_template_data({
    change_id = "kmkwpxtk",
    commit_id = "b7e72225",
    short_change_id = "kmkwpxtk",
    short_commit_id = "b7e72225",
    author = {
      name = "teernisse",
      email = "teernisse@visiostack.com",
      timestamp = "2025-06-13T09:24:49Z"
    },
    description = "(empty) Merge branch '2624-create-graph-of-all-rul-cards' into 'master'",
    full_description = "(empty) Merge branch '2624-create-graph-of-all-rul-cards' into 'master'",
    current_working_copy = false,
    empty = true,
    mine = true,
    root = false,
    conflict = false,
    bookmarks = {},
    parents = {},
    symbol = "◆",
    graph_prefix = "◆    ",
    graph_suffix = "",
    complete_graph = "◆    kmkwpxtk teernisse@visiostack.com 2025-06-13 09:24:49",
    description_graph = "├─╮  " -- This is the graph pattern that should wrap
  }))
  
  -- Skip elided section for now, just test with next commit directly
  
  -- Add the next actual commit (much later)
  table.insert(commits, commit_module.from_template_data({
    change_id = "ryrvnnyt",
    commit_id = "fc76e7e8",
    short_change_id = "ryrvnnyt",
    short_commit_id = "fc76e7e8",
    author = {
      name = "teernisse",
      email = "teernisse@visiostack.com",
      timestamp = "2025-05-30T08:54:36Z"
    },
    description = "(empty) WIP use 404 if no measurement config data",
    full_description = "(empty) WIP use 404 if no measurement config data",
    current_working_copy = false,
    empty = true,
    mine = true,
    root = false,
    conflict = false,
    bookmarks = {},
    parents = {},
    symbol = "○",
    graph_prefix = "│ ○  ",
    graph_suffix = "",
    complete_graph = "│ ○  ryrvnnyt teernisse@visiostack.com 2025-05-30 08:54:36",
    description_graph = "│ │  " -- This is what should be considered for lookahead
  }))
  
  -- Test with width that would cause the first commit's description to wrap
  local window_width = 75 -- Force wrapping on 'master'
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
  
  print("Raw lines:")
  for i, line in ipairs(raw_lines) do
    print(string.format("%d: %s", i, line))
  end
  
  -- Check for the specific pattern
  print("\n=== Bug Analysis ===")
  for i, line in ipairs(raw_lines) do
    if line:find("'master'") then
      print(string.format("Found wrapped line %d: '%s'", i, line))
      if line:match("^├─╮") then
        print("  ✗ BUG: Line starts with original graph pattern '├─╮' (should be continuation)")
      elseif line:match("^│ │") then
        print("  ✓ FIXED: Line starts with proper continuation '│ │'")
      elseif line:match("^     ") or line:match("^%s%s%s%s%s") then
        print("  ✗ BUG: Line starts with spaces only (no graph characters)")
      else
        local prefix = line:sub(1, 10)
        print(string.format("  ? OTHER: Line starts with '%s'", prefix))
      end
    end
  end
  
  return raw_lines
end

-- Test what happens when next commit lookup fails
local function test_next_commit_lookup_failure()
  print("\n=== Testing Next Commit Lookup Failure ===")
  
  -- Single commit with no next commit
  local commits = {
    commit_module.from_template_data({
      change_id = "single",
      commit_id = "single",
      short_change_id = "single",
      short_commit_id = "single",
      author = {
        name = "Test",
        email = "test@example.com",
        timestamp = "2025-01-01T10:00:00Z"
      },
      description = "This is a very long single commit description that should wrap and demonstrate what happens when there is no next commit to look ahead to",
      full_description = "This is a very long single commit description that should wrap and demonstrate what happens when there is no next commit to look ahead to",
      current_working_copy = false,
      empty = false,
      mine = true,
      root = false,
      conflict = false,
      bookmarks = {},
      parents = {},
      symbol = "○",
      graph_prefix = "├─╮  ",
      graph_suffix = "",
      description_graph = "├─╮  " 
    })
  }
  
  local window_width = 60
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
  
  print("Raw lines:")
  for i, line in ipairs(raw_lines) do
    print(string.format("%d: %s", i, line))
  end
  
  print("\n=== Analysis ===")
  for i, line in ipairs(raw_lines) do
    if line:find("demonstrate") or line:find("next commit") then
      print(string.format("Found wrapped line %d: '%s'", i, line))
      local prefix = line:sub(1, 6)
      print(string.format("  Prefix: '%s'", prefix))
    end
  end
  
  return raw_lines
end

-- Run both tests
local function run_tests()
  local result1 = test_complex_graph_scenario()
  local result2 = test_next_commit_lookup_failure()
  
  print("\n=== Test Summary ===")
  print("These tests help identify issues with graph continuation in complex scenarios")
  
  return {
    complex_scenario = result1,
    no_next_commit = result2
  }
end

return {
  run_tests = run_tests,
  test_complex_graph_scenario = test_complex_graph_scenario,
  test_next_commit_lookup_failure = test_next_commit_lookup_failure
}