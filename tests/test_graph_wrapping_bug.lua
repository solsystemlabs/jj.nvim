-- Test to examine the current graph rendering behavior with text wrapping
-- This test will help us understand the extra | character bug before fixing it

local renderer = require('jj-nvim.core.renderer')
local commit_module = require('jj-nvim.core.commit')

-- Create test commits that demonstrate the bug
local function create_test_commits()
  local commits = {}
  
  -- First commit: has 2 graph columns
  table.insert(commits, commit_module.from_template_data({
    change_id = "koyumtms",
    commit_id = "ba1eb6d1",
    short_change_id = "koyumtms",
    short_commit_id = "ba1eb6d1",
    shortest_change_id = "ko",
    shortest_commit_id = "ba",
    author = {
      name = "teernisse",
      email = "teernisse@visiostack.com",
      timestamp = "2025-07-10T14:46:43Z"
    },
    description = "Implement view toggle system with Ctrl+T/Tab keybinds for unified selection and manage state transitions",
    full_description = "Implement view toggle system with Ctrl+T/Tab keybinds for unified selection and manage state transitions",
    current_working_copy = false,
    empty = false,
    mine = true,
    root = false,
    conflict = false,
    bookmarks = {},
    parents = {},
    symbol = "○",
    graph_prefix = "│ ○  ",
    graph_suffix = "",
    complete_graph = "│ ○  koyumtms teernisse@visiostack.com 2025-07-10 14:46:43",
    description_graph = "│ │  " -- This is the key - description has 2 graph columns
  }))
  
  -- Second commit: has only 1 graph column
  table.insert(commits, commit_module.from_template_data({
    change_id = "lqxvmnor",
    commit_id = "b00eee8d",
    short_change_id = "lqxvmnor",
    short_commit_id = "b00eee8d",
    shortest_change_id = "lq",
    shortest_commit_id = "b0",
    author = {
      name = "teernisse",
      email = "teernisse@visiostack.com",
      timestamp = "2025-07-10T14:07:06Z"
    },
    description = "Remove Space key from main window navigation, keep only in special selection modes",
    full_description = "Remove Space key from main window navigation, keep only in special selection modes",
    current_working_copy = false,
    empty = false,
    mine = true,
    root = false,
    conflict = false,
    bookmarks = {},
    parents = {},
    symbol = "○",
    graph_prefix = "○  ",
    graph_suffix = "",
    complete_graph = "○  lqxvmnor teernisse@visiostack.com 2025-07-10 14:07:06",
    description_graph = "│  " -- This has only 1 graph column
  }))
  
  return commits
end

-- Test the current rendering behavior
local function test_current_behavior()
  print("=== Testing Current Graph Rendering Behavior ===")
  
  local commits = create_test_commits()
  local window_width = 80 -- Force wrapping
  
  -- Render the commits
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
  
  print("Raw lines:")
  for i, line in ipairs(raw_lines) do
    print(string.format("%d: %s", i, line))
  end
  
  print("\nAnalyzing the bug:")
  print("1. First commit has description_graph = '│ │  ' (2 columns)")
  print("2. Second commit has description_graph = '│  ' (1 column)")
  print("3. When first commit's description wraps, it should look ahead to second commit")
  print("4. Since second commit only needs 1 column, wrapped lines should have 1 column, not 2")
  
  -- Look for the bug pattern
  local found_bug = false
  for i, line in ipairs(raw_lines) do
    if line:find("selection") and line:find("│ │") then
      print(string.format("BUG FOUND on line %d: %s", i, line))
      print("  ^ This should only have 1 | character, not 2")
      found_bug = true
    end
  end
  
  if not found_bug then
    print("Note: Bug pattern not found in this test - may need different window width or commit setup")
  end
  
  return highlighted_lines, raw_lines
end

-- Test function to analyze graph structure
local function analyze_graph_structure()
  print("\n=== Analyzing Graph Structure ===")
  
  local commits = create_test_commits()
  
  for i, commit in ipairs(commits) do
    print(string.format("Commit %d:", i))
    print(string.format("  complete_graph: '%s'", commit.complete_graph or "nil"))
    print(string.format("  description_graph: '%s'", commit.description_graph or "nil"))
    print(string.format("  graph_prefix: '%s'", commit.graph_prefix or "nil"))
    print(string.format("  symbol: '%s'", commit.symbol or "nil"))
  end
end

-- Run the tests
local function run_tests()
  analyze_graph_structure()
  local highlighted_lines, raw_lines = test_current_behavior()
  
  print("\n=== Test Summary ===")
  print("This test demonstrates the extra | character bug in graph rendering.")
  print("The bug occurs when wrapped lines use the current commit's graph structure")
  print("instead of analyzing what graph columns are needed based on the next commit.")
  
  return {
    highlighted_lines = highlighted_lines,
    raw_lines = raw_lines
  }
end

-- Return the test module
return {
  run_tests = run_tests,
  test_current_behavior = test_current_behavior,
  analyze_graph_structure = analyze_graph_structure,
  create_test_commits = create_test_commits
}