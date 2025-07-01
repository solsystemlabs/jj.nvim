-- Mock jj command utilities for testing
local M = {}

-- Sample jj log output for testing (with * separator format that parser expects)
M.SAMPLE_JJ_LOG_GRAPH = [[
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

-- Sample template data with proper field separators that parser expects
M.SAMPLE_JJ_LOG_TEMPLATE =
    "change_1234abcd\x1Fabcd1234\x1Fchange_1\x1Fabcd1234\x1Fc_1\x1Fa123\x1FTest User\x1Ftest@example.com\x1F2024-01-01T10:00:00Z\x1FInitial commit\x1FInitial commit\n\nThis is a longer description.\x1Ftrue\x1Ffalse\x1Ftrue\x1Ffalse\x1Ffalse\x1Fmain\x1F\x1E\n" ..
    "change_5678efgh\x1Fefgh5678\x1Fchange_2\x1Fefgh5678\x1Fc_2\x1Fe567\x1FAnother User\x1Fanother@example.com\x1F2024-01-01T11:00:00Z\x1FAdd feature\x1FAdd feature for testing\x1Ffalse\x1Ffalse\x1Ftrue\x1Ffalse\x1Ffalse\x1F\x1Fchange_1234abcd\x1E\n" ..
    "change_9012ijkl\x1Fijkl9012\x1Fchange_3\x1Fijkl9012\x1Fc_3\x1Fi901\x1FTest User\x1Ftest@example.com\x1F2024-01-01T12:00:00Z\x1FFix bug\x1FFix critical bug\x1Ffalse\x1Ftrue\x1Ftrue\x1Ffalse\x1Ffalse\x1Fbugfix\x1Fchange_5678efgh\x1E\n" ..
    "change_3456mnop\x1Fmnop3456\x1Fchange_4\x1Fmnop3456\x1Fc_4\x1Fm345\x1FMerge User\x1Fmerge@example.com\x1F2024-01-01T13:00:00Z\x1FMerge branches\x1FMerge feature into main\x1Ffalse\x1Ffalse\x1Ftrue\x1Ffalse\x1Ffalse\x1F\x1Fchange_9012ijkl\x1E\n" ..
    "change_7890qrst\x1Fqrst7890\x1Fchange_5\x1Fqrst7890\x1Fc_5\x1Fq789\x1FDev User\x1Fdev@example.com\x1F2024-01-01T14:00:00Z\x1FUpdate docs\x1FUpdate documentation\x1Ffalse\x1Ffalse\x1Ftrue\x1Ffalse\x1Ffalse\x1F\x1Fchange_3456mnop\x1E\n"

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

