-- Debug test to understand what's happening with the graph wrapping
local renderer = require('jj-nvim.core.renderer')
local commit_module = require('jj-nvim.core.commit')

-- Test the wrap_text_by_words function directly
local function debug_wrap_function()
  print("=== Testing wrap_text_by_words function directly ===")
  
  -- Access the internal function - this will fail, but let's see what we can do
  local text = "Implement view toggle system with Ctrl+T/Tab keybinds for unified selection"
  local graph_prefix = "│ │  "
  local continuation_prefix = "│  "
  local window_width = 80
  
  print(string.format("Text: %s", text))
  print(string.format("Graph prefix: '%s'", graph_prefix))
  print(string.format("Continuation prefix: '%s'", continuation_prefix))
  print(string.format("Window width: %d", window_width))
  print(string.format("Text length: %d", #text))
  print(string.format("Graph prefix length: %d", #graph_prefix))
  print(string.format("Total length: %d", #text + #graph_prefix))
  
  -- Check if wrapping should occur
  if #text + #graph_prefix > window_width then
    print("Text should wrap!")
  else
    print("Text should NOT wrap")
  end
end

-- Test by creating a commit with a very long description to force wrapping
local function test_forced_wrapping()
  print("=== Testing with forced wrapping ===")
  
  local long_description = "This is a very long description that should definitely wrap because it exceeds the window width by a significant amount and continues on for quite a while to ensure wrapping occurs"
  
  local commits = {}
  
  -- First commit with very long description and 2 graph columns
  table.insert(commits, commit_module.from_template_data({
    change_id = "test1",
    commit_id = "test1",
    short_change_id = "test1",
    short_commit_id = "test1",
    author = {
      name = "Test",
      email = "test@example.com",
      timestamp = "2025-07-10T14:46:43Z"
    },
    description = long_description,
    full_description = long_description,
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
    description_graph = "│ │  " -- 2 columns
  }))
  
  -- Second commit with 1 graph column
  table.insert(commits, commit_module.from_template_data({
    change_id = "test2",
    commit_id = "test2",
    short_change_id = "test2",
    short_commit_id = "test2",
    author = {
      name = "Test",
      email = "test@example.com",
      timestamp = "2025-07-10T14:07:06Z"
    },
    description = "Short description",
    full_description = "Short description",
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
    description_graph = "│  " -- 1 column
  }))
  
  -- Test with narrow window width to force wrapping
  local window_width = 60
  local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
  
  print(string.format("Window width: %d", window_width))
  print("Raw lines:")
  for i, line in ipairs(raw_lines) do
    print(string.format("%d: %s", i, line))
  end
  
  -- Look for wrapped lines
  local wrapped_lines_found = 0
  for i, line in ipairs(raw_lines) do
    if line:find("│ │  ") and not line:find("test1") then
      wrapped_lines_found = wrapped_lines_found + 1
      print(string.format("Found wrapped line %d: %s", wrapped_lines_found, line))
    end
  end
  
  print(string.format("Total wrapped lines found: %d", wrapped_lines_found))
  
  return raw_lines
end

-- Run the debug tests
local function run_debug_tests()
  print("=== Graph Wrapping Debug Tests ===")
  debug_wrap_function()
  local lines = test_forced_wrapping()
  print("=== Debug Tests Complete ===")
  return lines
end

return {
  run_debug_tests = run_debug_tests,
  debug_wrap_function = debug_wrap_function,
  test_forced_wrapping = test_forced_wrapping
}