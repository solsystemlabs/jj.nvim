local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('renderer', function()
  local renderer
  local mock_commits
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.core.renderer'] = nil
    renderer = require('jj-nvim.core.renderer')
    
    -- Create mock commits for testing
    mock_commits = mock_jj.create_mock_commits(3)
  end)

  describe('render_with_highlights', function()
    it('should render commits with highlights', function()
      local highlighted_lines, raw_lines = renderer.render_with_highlights(mock_commits, 'comfortable')
      
      assert.is_not_nil(highlighted_lines)
      assert.is_not_nil(raw_lines)
      assert.is_table(highlighted_lines)
      assert.is_table(raw_lines)
      assert.is_true(#highlighted_lines > 0)
      assert.is_true(#raw_lines > 0)
    end)
    
    it('should handle empty commit list', function()
      local highlighted_lines, raw_lines = renderer.render_with_highlights({}, 'comfortable')
      
      assert.is_table(highlighted_lines)
      assert.is_table(raw_lines)
      assert.equals(0, #highlighted_lines)
      assert.equals(0, #raw_lines)
    end)
    
    it('should handle different render modes', function()
      local modes = { 'compact', 'comfortable', 'detailed' }
      
      for _, mode in ipairs(modes) do
        local highlighted_lines, raw_lines = renderer.render_with_highlights(mock_commits, mode)
        
        assert.is_table(highlighted_lines, "Mode: " .. mode)
        assert.is_table(raw_lines, "Mode: " .. mode)
        assert.is_true(#highlighted_lines > 0, "Mode: " .. mode)
        assert.is_true(#raw_lines > 0, "Mode: " .. mode)
      end
    end)
  end)

  describe('render modes', function()
    it('compact mode should render single lines', function()
      local highlighted_lines, _ = renderer.render_with_highlights(mock_commits, 'compact')
      
      -- In compact mode, each commit should be on one line
      -- (assuming no graph connectors)
      local commit_lines = 0
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.text and line_data.text ~= "" then
          commit_lines = commit_lines + 1
        end
      end
      
      assert.is_true(commit_lines >= #mock_commits)
    end)
    
    it('comfortable mode should include descriptions', function()
      local highlighted_lines, _ = renderer.render_with_highlights(mock_commits, 'comfortable')
      
      -- Should find commit descriptions in the output
      local found_description = false
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.text and string.find(line_data.text, "Test commit") then
          found_description = true
          break
        end
      end
      
      assert.is_true(found_description, "Should include commit descriptions")
    end)
    
    it('detailed mode should include additional information', function()
      local highlighted_lines, _ = renderer.render_with_highlights(mock_commits, 'detailed')
      
      -- Should include more detailed information
      assert.is_true(#highlighted_lines > 0)
      
      -- Should be at least as many lines as comfortable mode
      local comfortable_lines, _ = renderer.render_with_highlights(mock_commits, 'comfortable')
      assert.is_true(#highlighted_lines >= #comfortable_lines)
    end)
  end)

  describe('highlighting structure', function()
    it('should create proper highlight structure', function()
      local highlighted_lines, _ = renderer.render_with_highlights(mock_commits, 'comfortable')
      
      for i, line_data in ipairs(highlighted_lines) do
        assert.is_table(line_data, "Line " .. i .. " should be a table")
        test_utils.assert_has_key(line_data, 'text', "Line " .. i .. " should have text")
        
        assert.is_string(line_data.text, "Text should be string")
        
        -- The renderer may use either 'highlights' or 'segments' depending on implementation
        if line_data.highlights then
          assert.is_table(line_data.highlights, "Highlights should be table")
          
          -- Check highlight structure
          for j, highlight in ipairs(line_data.highlights) do
            assert.is_table(highlight, "Highlight " .. j .. " should be table")
            test_utils.assert_has_key(highlight, 'group', "Highlight should have group")
            test_utils.assert_has_key(highlight, 'start_col', "Highlight should have start_col")
            test_utils.assert_has_key(highlight, 'end_col', "Highlight should have end_col")
            
            assert.is_string(highlight.group, "Highlight group should be string")
            assert.is_number(highlight.start_col, "Start col should be number")
            assert.is_number(highlight.end_col, "End col should be number")
            assert.is_true(highlight.start_col >= 0, "Start col should be >= 0")
            assert.is_true(highlight.end_col >= highlight.start_col, "End col should be >= start col")
          end
        elseif line_data.segments then
          assert.is_table(line_data.segments, "Segments should be table")
          
          -- Check segment structure (alternative highlight format)
          for j, segment in ipairs(line_data.segments) do
            assert.is_table(segment, "Segment " .. j .. " should be table")
            test_utils.assert_has_key(segment, 'text', "Segment should have text")
            assert.is_string(segment.text, "Segment text should be string")
            
            -- Highlight field is optional (some segments might just be text/spacers)
            if segment.highlight then
              assert.is_string(segment.highlight, "Segment highlight should be string")
            end
          end
        end
      end
    end)
    
    it('should apply symbol highlighting', function()
      local highlighted_lines, _ = renderer.render_with_highlights(mock_commits, 'comfortable')
      
      -- Should find symbol highlights (could be in highlights or segments)
      local found_symbol_highlight = false
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.highlights then
          for _, highlight in ipairs(line_data.highlights) do
            if highlight.group and string.find(highlight.group, "Symbol") then
              found_symbol_highlight = true
              break
            end
          end
        elseif line_data.segments then
          for _, segment in ipairs(line_data.segments) do
            if segment.highlight and (string.find(segment.highlight, "Symbol") or 
                                     string.find(segment.highlight, "Ansi")) then
              found_symbol_highlight = true
              break
            end
          end
        end
        if found_symbol_highlight then break end
      end
      
      assert.is_true(found_symbol_highlight, "Should apply symbol highlighting")
    end)
    
    it('should apply commit ID highlighting', function()
      local highlighted_lines, _ = renderer.render_with_highlights(mock_commits, 'comfortable')
      
      -- Should find commit ID highlights (could be in highlights or segments)
      local found_commit_id_highlight = false
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.highlights then
          for _, highlight in ipairs(line_data.highlights) do
            if highlight.group and (
              string.find(highlight.group, "CommitId") or 
              string.find(highlight.group, "ChangeId")
            ) then
              found_commit_id_highlight = true
              break
            end
          end
        elseif line_data.segments then
          for _, segment in ipairs(line_data.segments) do
            if segment.highlight and (string.find(segment.highlight, "Ansi256") or
                                     string.find(segment.text, "change_") or
                                     string.find(segment.text, "commit_")) then
              found_commit_id_highlight = true
              break
            end
          end
        end
        if found_commit_id_highlight then break end
      end
      
      assert.is_true(found_commit_id_highlight, "Should apply commit ID highlighting")
    end)
  end)

  describe('graph rendering', function()
    it('should preserve graph structure', function()
      local highlighted_lines, _ = renderer.render_with_highlights(mock_commits, 'comfortable')
      
      -- Should find graph symbols in the output
      local found_graph_symbol = false
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.text and (
          string.find(line_data.text, "@") or 
          string.find(line_data.text, "○") or
          string.find(line_data.text, "◆") or
          string.find(line_data.text, "×")
        ) then
          found_graph_symbol = true
          break
        end
      end
      
      assert.is_true(found_graph_symbol, "Should preserve graph symbols")
    end)
    
    it('should handle graph prefixes and suffixes', function()
      -- Create commits with specific graph data using proper commit objects
      local commit_module = require('jj-nvim.core.commit')
      local test_commits = {
        commit_module.from_template_data({
          change_id = "test_change",
          commit_id = "test_commit",
          short_change_id = "test_ch",
          short_commit_id = "test_co",
          shortest_change_id = "tc",
          shortest_commit_id = "tc",
          author = { name = "Test", email = "test@example.com", timestamp = "2024-01-01T10:00:00Z" },
          description = "Test commit",
          full_description = "Test commit",
          current_working_copy = false,
          empty = false,
          mine = true,
          root = false,
          conflict = false,
          bookmarks = {},
          parents = {},
          symbol = "@",
          graph_prefix = "@  ",
          graph_suffix = " main",
          graph_line = "@  ◆ test_co main"
        })
      }
      
      local highlighted_lines, _ = renderer.render_with_highlights(test_commits, 'comfortable')
      
      assert.is_true(#highlighted_lines > 0)
      
      -- Should find the graph prefix in the output
      local found_prefix = false
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.text and string.find(line_data.text, "@") then
          found_prefix = true
          break
        end
      end
      
      assert.is_true(found_prefix, "Should include graph prefix")
    end)
  end)

  describe('special commit types', function()
    it('should handle current working copy commits', function()
      local wc_commits = mock_jj.create_mock_commits(1)
      wc_commits[1].current_working_copy = true
      wc_commits[1].symbol = "@"
      
      local highlighted_lines, _ = renderer.render_with_highlights(wc_commits, 'comfortable')
      
      -- Should find working copy symbol
      local found_wc_symbol = false
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.text and string.find(line_data.text, "@") then
          found_wc_symbol = true
          break
        end
      end
      
      assert.is_true(found_wc_symbol, "Should render working copy symbol")
    end)
    
    it('should handle empty commits', function()
      local empty_commits = mock_jj.create_mock_commits(1)
      empty_commits[1].empty = true
      
      local highlighted_lines, _ = renderer.render_with_highlights(empty_commits, 'comfortable')
      
      assert.is_true(#highlighted_lines > 0)
      -- Should render without errors
    end)
    
    it('should handle conflict commits', function()
      -- Create a conflict commit using proper commit object
      local commit_module = require('jj-nvim.core.commit')
      local conflict_commits = {
        commit_module.from_template_data({
          change_id = "conflict_change",
          commit_id = "conflict_commit",
          short_change_id = "conf_ch",
          short_commit_id = "conf_co",
          author = { name = "Test", email = "test@example.com", timestamp = "2024-01-01T10:00:00Z" },
          description = "Conflict commit",
          full_description = "Conflict commit",
          current_working_copy = false,
          empty = false,
          mine = true,
          root = false,
          conflict = true,
          bookmarks = {},
          parents = {},
          symbol = "×",
          graph_prefix = "×  ",
          graph_suffix = "",
        })
      }
      
      local highlighted_lines, _ = renderer.render_with_highlights(conflict_commits, 'comfortable')
      
      -- Should render without errors and have content
      assert.is_true(#highlighted_lines > 0, "Should render conflict commit")
      
      -- Check that the conflict data is preserved in the commit
      local commit = conflict_commits[1]
      assert.is_true(commit.conflict, "Commit should be marked as conflict")
      assert.equals("×", commit.symbol, "Commit should have conflict symbol")
    end)
  end)

  describe('bookmark rendering', function()
    it('should render bookmarks when present', function()
      local bookmark_commits = mock_jj.create_mock_commits(1)
      bookmark_commits[1].bookmarks = {"main", "feature"}
      
      local highlighted_lines, _ = renderer.render_with_highlights(bookmark_commits, 'comfortable')
      
      -- Should find bookmark references
      local found_bookmark = false
      for _, line_data in ipairs(highlighted_lines) do
        if line_data.text and (
          string.find(line_data.text, "main") or 
          string.find(line_data.text, "feature")
        ) then
          found_bookmark = true
          break
        end
      end
      
      assert.is_true(found_bookmark, "Should render bookmarks")
    end)
    
    it('should handle empty bookmark list', function()
      local no_bookmark_commits = mock_jj.create_mock_commits(1)
      no_bookmark_commits[1].bookmarks = {}
      
      local highlighted_lines, _ = renderer.render_with_highlights(no_bookmark_commits, 'comfortable')
      
      assert.is_true(#highlighted_lines > 0)
      -- Should render without errors
    end)
  end)

  describe('error handling', function()
    it('should handle nil commits', function()
      local highlighted_lines, raw_lines = renderer.render_with_highlights(nil, 'comfortable')
      
      assert.is_table(highlighted_lines)
      assert.is_table(raw_lines)
      assert.equals(0, #highlighted_lines)
      assert.equals(0, #raw_lines)
    end)
    
    it('should handle invalid render mode', function()
      local highlighted_lines, raw_lines = renderer.render_with_highlights(mock_commits, 'invalid_mode')
      
      assert.is_table(highlighted_lines)
      assert.is_table(raw_lines)
      -- Should fallback to a default mode
      assert.is_true(#highlighted_lines > 0)
    end)
    
    it('should handle commits with missing fields', function()
      -- Create commit with minimal data using proper commit object
      local commit_module = require('jj-nvim.core.commit')
      local incomplete_commits = {
        commit_module.from_template_data({
          short_commit_id = "test123",
          description = "Test",
          symbol = "○"
          -- Missing many fields - the commit object should handle this gracefully
        })
      }
      
      local highlighted_lines, raw_lines = renderer.render_with_highlights(incomplete_commits, 'comfortable')
      
      assert.is_table(highlighted_lines)
      assert.is_table(raw_lines)
      -- Should handle gracefully without crashing
    end)
  end)

  describe('graph wrapping bug fix', function()
    it('should use lookahead to reduce vertical bars in wrapped lines', function()
      local commit_module = require('jj-nvim.core.commit')
      
      -- Create test commits that demonstrate the bug fix
      local commits = {
        -- First commit: has 2 graph columns with long description that will wrap
        commit_module.from_template_data({
          change_id = "test1",
          commit_id = "test1",
          short_change_id = "test1",
          short_commit_id = "test1",
          author = {
            name = "Test",
            email = "test@example.com",
            timestamp = "2025-01-01T10:00:00Z"
          },
          description = "This is a very long description that should definitely wrap because it exceeds the window width significantly",
          full_description = "This is a very long description that should definitely wrap because it exceeds the window width significantly",
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
        }),
        -- Second commit: has only 1 graph column
        commit_module.from_template_data({
          change_id = "test2",
          commit_id = "test2",
          short_change_id = "test2",
          short_commit_id = "test2",
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
          graph_prefix = "○  ",
          graph_suffix = "",
          description_graph = "│  " -- 1 column
        })
      }
      
      -- Test with narrow width to force wrapping
      local window_width = 60
      local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
      
      -- Should have wrapped lines
      assert.is_true(#raw_lines > 2, "Should have wrapped lines")
      
      -- Find the wrapped lines (lines that contain part of the description but not the first line)
      local wrapped_lines = {}
      for i, line in ipairs(raw_lines) do
        if line:find("wrap because") or line:find("significantly") then
          table.insert(wrapped_lines, line)
        end
      end
      
      -- Should have found wrapped lines
      assert.is_true(#wrapped_lines > 0, "Should find wrapped lines")
      
      -- Wrapped lines should have the correct structure based on next commit's pattern
      for _, line in ipairs(wrapped_lines) do
        -- Should start with appropriate vertical bar pattern from next commit
        -- Should not start with complex graph characters like "├─╯"
        assert.is_false(line:match("^├"), "Wrapped line should not start with complex graph characters: " .. line)
        -- Should have proper indentation (starts with "│" and has spaces for alignment)
        assert.is_true(line:match("^│"), "Wrapped line should start with vertical bar: " .. line)
        -- Should have sufficient spacing for proper alignment
        assert.is_true(#line > 5, "Wrapped line should have sufficient length for content: " .. line)
      end
    end)
    
    it('should handle different column reduction scenarios', function()
      local commit_module = require('jj-nvim.core.commit')
      
      -- Test 3 columns -> 2 columns
      local commits = {
        commit_module.from_template_data({
          change_id = "test3col",
          commit_id = "test3col",
          short_change_id = "test3col",
          short_commit_id = "test3col",
          author = {
            name = "Test",
            email = "test@example.com",
            timestamp = "2025-01-01T10:00:00Z"
          },
          description = "Another very long description that should wrap and demonstrate the lookahead functionality",
          full_description = "Another very long description that should wrap and demonstrate the lookahead functionality",
          current_working_copy = false,
          empty = false,
          mine = true,
          root = false,
          conflict = false,
          bookmarks = {},
          parents = {},
          symbol = "○",
          graph_prefix = "│ │ ○  ",
          graph_suffix = "",
          description_graph = "│ │ │  " -- 3 columns
        }),
        commit_module.from_template_data({
          change_id = "test2col",
          commit_id = "test2col",
          short_change_id = "test2col",
          short_commit_id = "test2col",
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
          graph_prefix = "│ ○  ",
          graph_suffix = "",
          description_graph = "│ │  " -- 2 columns
        })
      }
      
      local window_width = 60
      local highlighted_lines, raw_lines = renderer.render_with_highlights(commits, 'comfortable', window_width)
      
      -- Find wrapped lines
      local wrapped_lines = {}
      for i, line in ipairs(raw_lines) do
        if line:find("demonstrate") or line:find("functionality") then
          table.insert(wrapped_lines, line)
        end
      end
      
      -- Should have wrapped lines
      assert.is_true(#wrapped_lines > 0, "Should find wrapped lines")
      
      -- Wrapped lines should have only 2 vertical bars (not 3)
      for _, line in ipairs(wrapped_lines) do
        -- Should start with "│ │ " (2 bars) not "│ │ │ " (3 bars)
        assert.is_true(line:match("^│ │ [^│]"), "Wrapped line should have only 2 vertical bars: " .. line)
      end
    end)
  end)
end)