-- Test both scenarios mentioned by the user
local renderer = require('jj-nvim.core.renderer')
local commit_module = require('jj-nvim.core.commit')

local function test_scenario_1()
  print("=== Testing Scenario 1: Should have 2 vertical bars ===")
  print("Expected: '│ │  'master' ▶'")
  
  local commits = {}
  
  -- First commit: merge commit that wraps
  table.insert(commits, commit_module.from_template_data({
    change_id = "kmkwpxtk",
    commit_id = "b7e72225",
    short_change_id = "kmkwpxtk",
    short_commit_id = "b7e72225",
    author = { name = "teernisse", email = "teernisse@visiostack.com", timestamp = "2025-06-13T09:24:49Z" },
    description = "(empty) Merge branch '2624-create-graph-of-all-rul-cards' into 'master'",
    full_description = "(empty) Merge branch '2624-create-graph-of-all-rul-cards' into 'master'",
    current_working_copy = false, empty = true, mine = true, root = false, conflict = false,
    bookmarks = {}, parents = {}, symbol = "◆", graph_prefix = "◆    ", graph_suffix = "",
    description_graph = "├─╮  "
  }))
  
  -- Next commit: has pattern that should determine continuation
  table.insert(commits, commit_module.from_template_data({
    change_id = "ryrvnnyt", commit_id = "fc76e7e8", short_change_id = "ryrvnnyt", short_commit_id = "fc76e7e8",
    author = { name = "teernisse", email = "teernisse@visiostack.com", timestamp = "2025-05-30T08:54:36Z" },
    description = "(empty) WIP use 404 if no measurement config data", full_description = "(empty) WIP use 404 if no measurement config data",
    current_working_copy = false, empty = true, mine = true, root = false, conflict = false,
    bookmarks = {}, parents = {}, symbol = "○", graph_prefix = "│ ○  ", graph_suffix = "",
    description_graph = "├─╯  " -- This should be interpreted as │ │   (2 vertical bars)
  }))
  
  local window_width = 75
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
  
  for i, line in ipairs(raw_lines) do
    print(string.format("%d: %s", i, line))
    if line:find("'master'") then
      if line:match("^│ │  ") then
        print("  ✓ CORRECT: Has 2 vertical bars")
      elseif line:match("^│    ") then
        print("  ✗ WRONG: Has only 1 vertical bar")
      else
        print("  ? OTHER: " .. line:sub(1, 10))
      end
    end
  end
  
  return raw_lines
end

local function test_scenario_2()
  print("\n=== Testing Scenario 2: Should have 1 vertical bar ===")
  print("Expected: '│    charts displaying'")
  
  local commits = {}
  
  -- First commit: has wrapping description
  table.insert(commits, commit_module.from_template_data({
    change_id = "tulskzpv", commit_id = "fa931737", short_change_id = "tulskzpv", short_commit_id = "fa931737",
    author = { name = "teernisse", email = "teernisse@visiostack.com", timestamp = "2025-07-10T19:29:51Z" },
    description = "feat: Initial work to get all data fetched for crosslevel and charts displaying",
    full_description = "feat: Initial work to get all data fetched for crosslevel and charts displaying",
    current_working_copy = false, empty = false, mine = true, root = false, conflict = false,
    bookmarks = {}, parents = {}, symbol = "○", graph_prefix = "│ ○  ", graph_suffix = "",
    description_graph = "├─╯  "
  }))
  
  -- Next commit: has pattern that should determine continuation  
  table.insert(commits, commit_module.from_template_data({
    change_id = "xmnonqsw", commit_id = "53f76288", short_change_id = "xmnonqsw", short_commit_id = "53f76288",
    author = { name = "jdefting", email = "jdefting@visiostack.com", timestamp = "2025-07-14T10:06:48Z" },
    description = "(empty) Merge branch '3152-feature-template' into 'master'",
    full_description = "(empty) Merge branch '3152-feature-template' into 'master'",
    current_working_copy = false, empty = true, mine = true, root = false, conflict = false,
    bookmarks = {"master"}, parents = {}, symbol = "◆", graph_prefix = "◆    ", graph_suffix = "",
    description_graph = "├─╮  " -- This should be interpreted as │ │ │   (but only first │ should be used)
  }))
  
  local window_width = 70
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
  
  for i, line in ipairs(raw_lines) do
    print(string.format("%d: %s", i, line))
    if line:find("charts displaying") then
      if line:match("^│    ") then
        print("  ✓ CORRECT: Has 1 vertical bar + 3 spaces")
      elseif line:match("^│ │  ") then
        print("  ✗ WRONG: Has 2 vertical bars")
      else
        print("  ? OTHER: " .. line:sub(1, 10))
      end
    end
  end
  
  return raw_lines
end

local function run_tests()
  local result1 = test_scenario_1()
  local result2 = test_scenario_2()
  
  print("\n=== Summary ===")
  print("Testing the two scenarios reported by the user")
  
  return { scenario1 = result1, scenario2 = result2 }
end

return {
  run_tests = run_tests,
  test_scenario_1 = test_scenario_1,
  test_scenario_2 = test_scenario_2
}