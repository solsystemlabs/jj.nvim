-- Test the exact scenario from the user's report
local renderer = require('jj-nvim.core.renderer')
local commit_module = require('jj-nvim.core.commit')

local function test_real_scenario()
  print("=== Testing Real Scenario ===")
  
  local commits = {}
  
  -- First commit: the one with the long description that wraps
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
    description_graph = "├─╯  " -- This is the actual pattern from the user's example
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
    description_graph = "│  " -- This is the pattern from the user's example
  }))
  
  -- Test with width that would cause wrapping
  local window_width = 80
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
        print("  ✓ Correct: Line starts with '│  ' (1 bar + 2 spaces)")
      elseif line:match("^  ") then
        print("  ✗ Bug: Line starts with '  ' (0 bars)")
      else
        print("  ? Other pattern")
      end
    end
  end
  
  return raw_lines
end

return {
  test_real_scenario = test_real_scenario
}