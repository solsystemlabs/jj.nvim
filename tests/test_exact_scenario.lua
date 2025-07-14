-- Test the exact scenario from the user's report
local renderer = require('jj-nvim.core.renderer')
local commit_module = require('jj-nvim.core.commit')

local function test_exact_user_scenario()
  print("=== Testing Exact User Scenario ===")
  
  local commits = {}
  
  -- Recreate the exact scenario from the user's report:
  -- │ ○  koyumtms teernisse@visiostack.com 2025-07-10 14:46:43 
  -- │ │  ba1eb6d1 
  -- ├─╯  Implement view toggle system with Ctrl+T/Tab keybinds for unified 
  -- │ │  selection     <- This should be "│  selection" (1 bar, not 2)
  -- ○  lqxvmnor teernisse@visiostack.com 2025-07-10 14:07:06 b00eee8d 
  
  -- First commit: the one that causes the problem
  table.insert(commits, commit_module.from_template_data({
    change_id = "koyumtms",
    commit_id = "ba1eb6d1",
    short_change_id = "koyumtms",
    short_commit_id = "ba1eb6d1",
    author = {
      name = "teernisse",
      email = "teernisse@visiostack.com",
      timestamp = "2025-07-10T14:46:43Z"
    },
    description = "Implement view toggle system with Ctrl+T/Tab keybinds for unified selection",
    full_description = "Implement view toggle system with Ctrl+T/Tab keybinds for unified selection",
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
    description_graph = "├─╯  " -- This is the description graph that should wrap
  }))
  
  -- Second commit: the one below it
  table.insert(commits, commit_module.from_template_data({
    change_id = "lqxvmnor",
    commit_id = "b00eee8d",
    short_change_id = "lqxvmnor",
    short_commit_id = "b00eee8d",
    author = {
      name = "teernisse",
      email = "teernisse@visiostack.com",
      timestamp = "2025-07-10T14:07:06Z"
    },
    description = "Remove Space key from main window navigation",
    full_description = "Remove Space key from main window navigation",
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
    description_graph = "│  " -- This is what the wrapped line should match
  }))
  
  -- Test with width that would cause the first commit's description to wrap
  local window_width = 75 -- Smaller width to force wrapping
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
  
  print("Raw lines:")
  for i, line in ipairs(raw_lines) do
    print(string.format("%d: %s", i, line))
  end
  
  -- Check for the specific pattern
  print("\n=== Pattern Analysis ===")
  for i, line in ipairs(raw_lines) do
    if line:find("selection") and not line:find("Implement") then
      print(string.format("Found wrapped line %d: %s", i, line))
      if line:match("^│  ") then
        print("  ✓ FIXED: Line starts with '│  ' (1 bar + 2 spaces)")
      elseif line:match("^  ") then
        print("  ✗ BUG: Line starts with '  ' (0 bars)")
      elseif line:match("^├─╯  ") then
        print("  ✗ BUG: Line starts with '├─╯  ' (should be continuation graph)")
      else
        print("  ? Other pattern: " .. line:sub(1, 10))
      end
    end
  end
  
  return raw_lines
end

return {
  test_exact_user_scenario = test_exact_user_scenario
}