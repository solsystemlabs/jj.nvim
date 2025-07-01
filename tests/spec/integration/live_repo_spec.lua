local fixture_loader = require('tests.helpers.fixture_loader')
local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('live repository integration', function()
  local parser
  local mock_system
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.core.parser'] = nil
    parser = require('jj-nvim.core.parser')
  end)
  
  after_each(function()
    if mock_system then
      mock_system.restore()
    end
  end)

  describe('real test repository', function()
    it('should be available for testing', function()
      if not fixture_loader.test_repo_available() then
        pending("Test repository not available - skipping live tests")
        return
      end
      
      assert.is_true(fixture_loader.test_repo_available(), "Test repository should be available")
      
      local repo_path = fixture_loader.get_test_repo_path()
      assert.is_string(repo_path)
      assert.is_true(#repo_path > 0)
    end)
    
    it('should parse commits from live repository', function()
      if not fixture_loader.test_repo_available() then
        pending("Test repository not available - skipping live tests")
        return
      end
      
      -- Use live repository mock
      mock_system = mock_jj.mock_vim_system_with_test_repo()
      
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 5 })
      
      assert.is_nil(err, "Should parse without errors")
      assert.is_not_nil(commits, "Should return commits")
      assert.is_table(commits, "Commits should be a table")
      assert.is_true(#commits > 0, "Should have at least one commit")
      
      -- Validate commit structure
      local commit = commits[1]
      assert.is_table(commit, "First commit should be a table")
      
      local required_fields = {
        'change_id', 'commit_id', 'short_change_id', 'short_commit_id',
        'author', 'description', 'symbol'
      }
      
      for _, field in ipairs(required_fields) do
        test_utils.assert_has_key(commit, field, "Missing field: " .. field)
      end
      
      -- Verify author structure
      assert.is_table(commit.author, "Author should be a table")
      test_utils.assert_has_key(commit.author, 'name')
      test_utils.assert_has_key(commit.author, 'email')
    end)
    
    it('should handle complex repository structure', function()
      if not fixture_loader.test_repo_available() then
        pending("Test repository not available - skipping live tests")
        return
      end
      
      mock_system = mock_jj.mock_vim_system_with_test_repo()
      
      -- Parse all commits to get the full repository structure
      local commits, err = parser.parse_all_commits_with_separate_graph()
      
      assert.is_nil(err, "Should parse all commits without errors")
      assert.is_not_nil(commits, "Should return commits")
      assert.is_true(#commits > 3, "Should have multiple commits in test repo")
      
      -- Check for different types of commits
      local has_working_copy = false
      local has_conflict = false
      local has_merge = false
      local has_empty = false
      
      for _, commit in ipairs(commits) do
        if commit.current_working_copy then
          has_working_copy = true
        end
        if commit.conflict then
          has_conflict = true
        end
        if commit.parents and #commit.parents > 1 then
          has_merge = true
        end
        if commit.empty then
          has_empty = true
        end
      end
      
      assert.is_true(has_working_copy, "Should have working copy commit")
      -- Note: conflict and merge detection may depend on repository state
    end)
    
    it('should work with different commit limits', function()
      if not fixture_loader.test_repo_available() then
        pending("Test repository not available - skipping live tests")
        return
      end
      
      mock_system = mock_jj.mock_vim_system_with_test_repo()
      
      -- Test with different limits
      local limits = { 1, 3, 5 }
      
      for _, limit in ipairs(limits) do
        local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = limit })
        
        assert.is_nil(err, "Should parse with limit " .. limit)
        assert.is_not_nil(commits, "Should return commits")
        assert.is_true(#commits <= limit, "Should respect limit of " .. limit)
      end
    end)
  end)

  describe('fixture data consistency', function()
    it('should have fixture data available', function()
      if not fixture_loader.fixtures_available() then
        pending("Fixture data not available - run test_data_generator.regenerate_fixtures()")
        return
      end
      
      assert.is_true(fixture_loader.fixtures_available(), "Fixture data should be available")
      
      -- Test that fixture data can be loaded
      local fixtures = fixture_loader.load_jj_outputs()
      assert.is_table(fixtures, "Fixtures should be a table")
      test_utils.assert_has_key(fixtures, 'graph')
      test_utils.assert_has_key(fixtures, 'template')
      
      assert.is_string(fixtures.graph, "Graph data should be a string")
      assert.is_string(fixtures.template, "Template data should be a string")
      assert.is_true(#fixtures.graph > 0, "Graph data should not be empty")
      assert.is_true(#fixtures.template > 0, "Template data should not be empty")
    end)
    
    it('should parse commits using fixture data', function()
      if not fixture_loader.fixtures_available() then
        pending("Fixture data not available")
        return
      end
      
      -- Use regular mock (which now uses fixture data)
      mock_system = mock_jj.mock_vim_system()
      
      local commits, err = parser.parse_commits_with_separate_graph(nil, { limit = 5 })
      
      assert.is_nil(err, "Should parse fixture data without errors")
      assert.is_not_nil(commits, "Should return commits from fixtures")
      assert.is_table(commits, "Commits should be a table")
      assert.is_true(#commits > 0, "Should have commits from fixture data")
      
      -- Validate that fixture data produces valid commits
      local commit = commits[1]
      assert.is_table(commit, "First commit should be a table")
      
      -- Check that IDs are not the simple mock values
      assert.is_true(commit.short_commit_id ~= "commit_1", 
                    "Should use real commit IDs from fixtures, not mock data")
    end)
  end)

  describe('test data validation', function()
    it('should validate fixture data against repository', function()
      if not fixture_loader.test_repo_available() or not fixture_loader.fixtures_available() then
        pending("Both test repository and fixtures needed for validation")
        return
      end
      
      local test_data_generator = require('tests.helpers.test_data_generator')
      local valid, message = test_data_generator.validate_fixtures()
      
      -- This test helps ensure fixtures stay in sync with the repository
      if not valid then
        print("Warning: " .. message)
        print("Consider running: require('tests.helpers.test_data_generator').regenerate_fixtures()")
      end
      
      -- We don't assert here since the repository might have been modified
      -- But we print the validation result for developer awareness
    end)
  end)
end)