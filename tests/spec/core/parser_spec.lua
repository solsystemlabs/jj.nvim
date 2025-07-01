local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('parser', function()
  local parser
  local mock_system
  local mock_notify

  before_each(function()
    -- Reset module cache to ensure clean state
    package.loaded['jj-nvim.core.parser'] = nil
    parser = require('jj-nvim.core.parser')

    -- Set up mocks
    mock_system = mock_jj.mock_vim_system()
    mock_notify = mock_jj.mock_vim_notify()
  end)

  after_each(function()
    if mock_system then
      mock_system.restore()
    end
    if mock_notify then
      mock_notify.restore()
    end
  end)

  describe('parse_commits_with_separate_graph', function()
    it('should parse commits with graph data', function()
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 3 })

      assert.is_nil(err)
      assert.is_not_nil(commits)
      assert.is_table(commits)
      assert.is_true(#commits > 0)
    end)

    it('should handle empty repository', function()
      mock_system.restore()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "",
          stderr = ""
        },
        {
          code = 0,
          stdout = "",
          stderr = ""
        }
      })

      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 3 })

      assert.is_nil(err)
      assert.is_table(commits)
      assert.equals(0, #commits)
    end)

    it('should handle jj command errors', function()
      mock_system.restore()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 1,
          stdout = "",
          stderr = "jj: No repository found"
        }
      })

      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 3 })

      assert.is_nil(commits)
      assert.is_not_nil(err)
      assert.is_string(err)
      test_utils.assert_contains(err, "repository")
    end)
  end)

  describe('parse_all_commits_with_separate_graph', function()
    it('should parse all commits without limit', function()
      local commits, err = parser.parse_all_commits_with_separate_graph()

      assert.is_nil(err)
      assert.is_not_nil(commits)
      assert.is_table(commits)
    end)
  end)

  describe('commit structure validation', function()
    it('should create commits with required fields', function()
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 1 })

      assert.is_nil(err)
      assert.is_true(#commits > 0)

      local commit = commits[1]
      local required_fields = {
        'change_id', 'commit_id', 'short_change_id', 'short_commit_id',
        'author', 'description', 'current_working_copy', 'empty',
        'mine', 'root', 'conflict', 'bookmarks', 'parents',
        'symbol', 'graph_prefix', 'graph_suffix'
      }

      for _, field in ipairs(required_fields) do
        test_utils.assert_has_key(commit, field, "Missing required field: " .. field)
      end
    end)

    it('should have proper author structure', function()
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 1 })

      assert.is_nil(err)
      assert.is_true(#commits > 0)

      local author = commits[1].author
      assert.is_table(author)
      test_utils.assert_has_key(author, 'name')
      test_utils.assert_has_key(author, 'email')
      test_utils.assert_has_key(author, 'timestamp')
    end)

    it('should handle boolean fields correctly', function()
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 1 })

      assert.is_nil(err)
      assert.is_true(#commits > 0)

      local commit = commits[1]
      local boolean_fields = {
        'current_working_copy', 'empty', 'mine', 'root', 'conflict'
      }

      for _, field in ipairs(boolean_fields) do
        local value = commit[field]
        assert.is_true(type(value) == 'boolean',
          string.format("Field '%s' should be boolean, got %s", field, type(value)))
      end
    end)

    it('should handle array fields correctly', function()
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 1 })

      assert.is_nil(err)
      assert.is_true(#commits > 0)

      local commit = commits[1]
      assert.is_table(commit.bookmarks)
      assert.is_table(commit.parents)
    end)
  end)

  describe('graph parsing', function()
    it('should assign symbols correctly', function()
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 3 })

      assert.is_nil(err)
      assert.is_true(#commits > 0)

      for _, commit in ipairs(commits) do
        assert.is_string(commit.symbol)
        assert.is_true(#commit.symbol > 0)
        -- Should be one of the valid jj symbols
        local valid_symbols = { '@', '○', '◆', '×' }
        local found = false
        for _, valid_symbol in ipairs(valid_symbols) do
          if commit.symbol == valid_symbol then
            found = true
            break
          end
        end
        assert.is_true(found, "Invalid symbol: " .. commit.symbol)
      end
    end)

    it('should preserve graph structure', function()
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 3 })

      assert.is_nil(err)
      assert.is_true(#commits > 0)

      local commit_count = 0
      for _, commit in ipairs(commits) do
        if commit.type ~= "elided" then -- Only check actual commits, not elided entries
          commit_count = commit_count + 1
          -- Test that graph-related fields exist and are strings
          assert.is_string(commit.graph_prefix)
          assert.is_string(commit.graph_suffix)
          -- Symbol should be valid
          assert.is_true(commit.symbol ~= nil and commit.symbol ~= "", "Symbol should not be empty")
          -- The parser should assign a valid symbol from the graph
          local valid_symbols = { '@', '○', '◆', '×' }
          local found = false
          for _, valid_symbol in ipairs(valid_symbols) do
            if commit.symbol == valid_symbol then
              found = true
              break
            end
          end
          assert.is_true(found, "Should have valid symbol: " .. commit.symbol)
        end
      end

      -- Should have found at least one commit
      assert.is_true(commit_count > 0, "Should have found at least one commit")
    end)
  end)

  describe('template parsing', function()
    it('should parse field separators correctly', function()
      -- Test with mock data that has separators
      local test_template_data = table.concat({
        "change1", "commit1", "ch1", "co1", "c1", "c1",
        "Author Name", "author@email.com", "2024-01-01T10:00:00Z",
        "Description", "Full description", "true", "false", "true", "false", "false",
        "main,feature", "parent1,parent2"
      }, "\x1F") .. "\x1E"

      mock_system.restore()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "@  *co1\n",
          stderr = ""
        },
        {
          code = 0,
          stdout = test_template_data,
          stderr = ""
        }
      })

      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 1 })

      assert.is_nil(err)
      assert.is_true(#commits > 0)

      local commit = commits[1]
      assert.equals("change1", commit.change_id)
      assert.equals("commit1", commit.commit_id)
      assert.equals("Author Name", commit.author.name)
      assert.equals("author@email.com", commit.author.email)
      assert.is_true(commit.current_working_copy)
      assert.is_false(commit.empty)
      test_utils.assert_length(commit.bookmarks, 2)
      assert.equals("main", commit.bookmarks[1])
      assert.equals("feature", commit.bookmarks[2])
    end)
  end)

  describe('error handling', function()
    it('should handle malformed template data', function()
      mock_system.restore()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "@  ○ commit1\n",
          stderr = ""
        },
        {
          code = 0,
          stdout = "malformed data without proper separators",
          stderr = ""
        }
      })

      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 1 })

      -- Should handle gracefully - either return error or empty result
      if err then
        assert.is_string(err)
      else
        assert.is_table(commits)
        -- May be empty if data is malformed
      end
    end)

    it('should handle graph/template mismatch', function()
      mock_system.restore()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "@  ○ commit1\n○  ○ commit2\n",
          stderr = ""
        },
        {
          code = 0,
          stdout = "change1\x1Fcommit1\x1F...\x1E", -- Only one commit in template
          stderr = ""
        }
      })

      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 2 })

      -- Should handle mismatch gracefully
      if err then
        assert.is_string(err)
      else
        assert.is_table(commits)
        -- Should not crash
      end
    end)
  end)
end)

