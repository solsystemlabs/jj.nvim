-- Test the indentation fix for wrapped lines
local renderer = require('jj-nvim.core.renderer')
local commit_module = require('jj-nvim.core.commit')

local function test_indentation_scenarios()
  print("=== Testing Indentation Fix Scenarios ===")
  
  local scenarios = {
    {
      name = "4-char graph -> 2-char graph",
      current_graph = "├─╯  ", -- 4 characters
      next_graph = "│  ",      -- 2 characters  
      expected_continuation = "│    ", -- 1 bar + 3 spaces (total 4 chars)
      description = "Long description that should wrap to demonstrate proper indentation"
    },
    {
      name = "6-char graph -> 4-char graph", 
      current_graph = "│ │ ○  ", -- 6 characters
      next_graph = "│ │  ",     -- 4 characters
      expected_continuation = "│ │   ", -- 2 bars + 3 spaces (total 6 chars)
      description = "Another long description that should wrap with different graph structure"
    }
  }
  
  for i, scenario in ipairs(scenarios) do
    print(string.format("\n--- Scenario %d: %s ---", i, scenario.name))
    
    local commits = {
      commit_module.from_template_data({
        change_id = "test" .. i .. "a",
        commit_id = "test" .. i .. "a", 
        short_change_id = "test" .. i .. "a",
        short_commit_id = "test" .. i .. "a",
        author = {
          name = "Test",
          email = "test@example.com",
          timestamp = "2025-01-01T10:00:00Z"
        },
        description = scenario.description,
        full_description = scenario.description,
        current_working_copy = false,
        empty = false,
        mine = true,
        root = false,
        conflict = false,
        bookmarks = {},
        parents = {},
        symbol = "○",
        graph_prefix = scenario.current_graph,
        graph_suffix = "",
        description_graph = scenario.current_graph
      }),
      commit_module.from_template_data({
        change_id = "test" .. i .. "b",
        commit_id = "test" .. i .. "b",
        short_change_id = "test" .. i .. "b", 
        short_commit_id = "test" .. i .. "b",
        author = {
          name = "Test",
          email = "test@example.com",
          timestamp = "2025-01-01T10:00:00Z"
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
        graph_prefix = scenario.next_graph,
        graph_suffix = "",
        description_graph = scenario.next_graph
      })
    }
    
    local window_width = 60 -- Force wrapping
    local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
    
    print("Raw lines:")
    for j, line in ipairs(raw_lines) do
      print(string.format("%d: %s", j, line))
    end
    
    -- Find wrapped lines
    local wrapped_lines = {}
    for j, line in ipairs(raw_lines) do
      if line:find("demonstrate") or line:find("indentation") or line:find("structure") then
        table.insert(wrapped_lines, line)
        print(string.format("Found wrapped line %d: '%s'", j, line))
        
        -- Check if it starts with expected continuation pattern
        local line_start = line:sub(1, #scenario.expected_continuation)
        if line_start == scenario.expected_continuation then
          print(string.format("  ✓ Correct indentation: '%s' (length %d)", line_start, #line_start))
        else
          print(string.format("  ✗ Wrong indentation: got '%s' (length %d), expected '%s' (length %d)", 
                             line_start, #line_start, scenario.expected_continuation, #scenario.expected_continuation))
        end
      end
    end
    
    if #wrapped_lines == 0 then
      print("  ⚠ No wrapped lines found - may need longer description")
    end
  end
  
  return true
end

return {
  test_indentation_scenarios = test_indentation_scenarios
}