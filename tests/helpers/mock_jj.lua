-- Mock jj command utilities for testing
local M = {}

-- Load real fixture data
local fixture_loader = require('tests.helpers.fixture_loader')

-- Try to load real fixture data, fallback to simple mock if not available
local function get_sample_data()
  if fixture_loader.fixtures_available() then
    local fixtures = fixture_loader.load_jj_outputs()
    return fixtures.graph, fixtures.template
  else
    -- Fallback to simple mock data if fixtures not available
    local fallback_graph = [[
@  *abcd1234
│
○  *efgh5678
├─╮
│ ○  *ijkl9012
├─╯
○  *mnop3456
│
○  *qrst7890
]]
    
    local fallback_template = "change_1234abcd\x1Fabcd1234\x1Fchange_1\x1Fabcd1234\x1Fc_1\x1Fa123\x1FTest User\x1Ftest@example.com\x1F2024-01-01T10:00:00Z\x1FInitial commit\x1FInitial commit\n\nThis is a longer description.\x1Ftrue\x1Ffalse\x1Ftrue\x1Ffalse\x1Ffalse\x1Fmain\x1F\x1E\n"
    
    return fallback_graph, fallback_template
  end
end

-- Get the actual data (will use fixtures if available)
M.SAMPLE_JJ_LOG_GRAPH, M.SAMPLE_JJ_LOG_TEMPLATE = get_sample_data()

-- Create a mock that uses the live test repository if available
function M.mock_vim_system_with_test_repo()
  if not fixture_loader.test_repo_available() then
    return M.mock_vim_system() -- Fall back to regular mock
  end
  
  local original_system = vim.system
  local test_repo_path = fixture_loader.get_test_repo_path()
  
  vim.system = function(cmd, opts)
    -- Only handle jj commands
    if cmd[1] == 'jj' then
      -- Execute the actual jj command in the test repository using original system
      local test_cmd = vim.deepcopy(cmd)
      local test_result = original_system(test_cmd, {
        text = true,
        cwd = test_repo_path
      }):wait(3000)
      
      return {
        wait = function()
          return test_result
        end
      }
    end
    
    -- For non-jj commands, use original
    return original_system(cmd, opts)
  end
  
  return {
    restore = function()
      vim.system = original_system
    end
  }
end

-- Mock vim.system function for testing jj commands
function M.mock_vim_system(expected_commands)
  local call_count = 0
  local original_system = vim.system

  vim.system = function(cmd, opts)
    call_count = call_count + 1

    if expected_commands and expected_commands[call_count] then
      local expected = expected_commands[call_count]

      -- Return the mock result
      return {
        wait = function()
          return {
            code = expected.code or 0,
            stdout = expected.stdout or "",
            stderr = expected.stderr or "",
          }
        end
      }
    end

    -- Default mock response for jj log commands
    if cmd[1] == 'jj' and cmd[2] == 'log' then
      local has_template = false
      local has_no_graph = false
      local has_star_template = false

      for _, arg in ipairs(cmd) do
        if arg:find('change_id') then
          has_template = true
        end
        if arg == '--no-graph' then
          has_no_graph = true
        end
        if arg:find('%*') then -- Looking for * separator template
          has_star_template = true
        end
      end

      local stdout = ""
      if has_template and has_no_graph then
        -- This is the template data request
        stdout = M.SAMPLE_JJ_LOG_TEMPLATE
      elseif has_star_template then
        -- This is the graph request with * separators
        stdout = M.SAMPLE_JJ_LOG_GRAPH
      else
        -- Default graph output
        stdout = M.SAMPLE_JJ_LOG_GRAPH
      end

      return {
        wait = function()
          return {
            code = 0,
            stdout = stdout,
            stderr = "",
          }
        end
      }
    end

    -- Default error for unknown commands
    return {
      wait = function()
        return {
          code = 1,
          stdout = "",
          stderr = "Mock: Unknown command",
        }
      end
    }
  end

  return {
    restore = function()
      vim.system = original_system
    end,
    call_count = function()
      return call_count
    end
  }
end

-- Create mock commit objects for testing
function M.create_mock_commits(count)
  local commit_module = require('jj-nvim.core.commit')
  local commits = {}

  for i = 1, (count or 3) do
    local commit_data = {
      change_id = string.format("change_%d_full_id", i),
      commit_id = string.format("commit_%d_full_id", i),
      short_change_id = string.format("change_%d", i),
      short_commit_id = string.format("commit_%d", i),
      shortest_change_id = string.format("c_%d", i),
      shortest_commit_id = string.format("co_%d", i),
      author = {
        name = string.format("Test User %d", i),
        email = string.format("user%d@example.com", i),
        timestamp = string.format("2024-01-0%dT10:00:00Z", i)
      },
      description = string.format("Test commit %d", i),
      full_description = string.format("Test commit %d\n\nDetailed description for commit %d", i, i),
      current_working_copy = i == 1,
      empty = false,
      mine = true,
      root = false,
      conflict = false,
      bookmarks = i == 1 and { "main" } or {},
      parents = i > 1 and { string.format("commit_%d", i - 1) } or {},
      symbol = i == 1 and "@" or "○",
      graph_prefix = string.format("%s  ", i == 1 and "@" or "○"),
      graph_suffix = "",
      graph_line = string.format("%s  ◆ %s", i == 1 and "@" or "○", string.format("commit_%d", i))
    }

    -- Create proper Commit object using factory function
    table.insert(commits, commit_module.from_template_data(commit_data))
  end

  return commits
end

-- Mock vim notify for testing
function M.mock_vim_notify()
  local notifications = {}
  local original_notify = vim.notify

  vim.notify = function(msg, level)
    table.insert(notifications, {
      message = msg,
      level = level or vim.log.levels.INFO
    })
  end

  return {
    restore = function()
      vim.notify = original_notify
    end,
    get_notifications = function()
      return notifications
    end,
    clear = function()
      notifications = {}
    end
  }
end

return M

