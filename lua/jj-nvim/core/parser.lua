local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_module = require('jj-nvim.core.commit')

-- Template to extract commit data using jj's template syntax
-- Each field is separated by | delimiter, with explicit newlines between commits
local COMMIT_TEMPLATE = [[change_id ++ "|" ++ commit_id ++ "|" ++ change_id.short(8) ++ "|" ++ commit_id.short(8) ++ "|" ++ author.name() ++ "|" ++ author.email() ++ "|" ++ author.timestamp() ++ "|" ++ description.first_line() ++ "|" ++ if(current_working_copy, "true", "false") ++ "|" ++ if(empty, "true", "false") ++ "|" ++ if(mine, "true", "false") ++ "|" ++ if(root, "true", "false") ++ "|" ++ bookmarks.join(",") ++ "|" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\n"]]

-- Parse commits using jj template system
M.parse_commits = function(revset, options)
  options = options or {}
  local limit = options.limit or 100
  
  -- Build jj log command with comprehensive template
  local args = {
    'log',
    '--template', COMMIT_TEMPLATE,
    '--no-graph',
    '--no-pager',
    '-r', revset or 'all()',
    '--limit', tostring(limit)
  }
  
  -- Execute the command
  local result, err = commands.execute(args, { silent = true })
  if not result then
    return nil, err or "Failed to execute jj log command"
  end
  
  -- Parse delimited output - each line contains all commit data separated by |
  local commits = {}
  local line_num = 0
  
  for line in result:gmatch('[^\r\n]+') do
    line_num = line_num + 1
    line = line:match("^%s*(.-)%s*$") -- trim whitespace
    
    if line ~= "" then
      local parts = vim.split(line, '|', { plain = true })
      
      if #parts >= 14 then
        -- Parse the delimited fields
        local commit_data = {
          change_id = parts[1] or "",
          commit_id = parts[2] or "",
          short_change_id = parts[3] or "",
          short_commit_id = parts[4] or "",
          author = {
            name = parts[5] or "",
            email = parts[6] or "",
            timestamp = parts[7] or ""
          },
          description = parts[8] or "",
          current_working_copy = parts[9] == "true",
          empty = parts[10] == "true",
          mine = parts[11] == "true",
          root = parts[12] == "true",
          bookmarks = parts[13] ~= "" and vim.split(parts[13], ',', { plain = true }) or {},
          parents = parts[14] ~= "" and vim.split(parts[14], ',', { plain = true }) or {}
        }
        
        -- Create commit object from parsed data
        local commit = commit_module.from_template_data(commit_data)
        table.insert(commits, commit)
      else
        vim.notify(
          string.format("Failed to parse commit data on line %d (not enough fields): %s", line_num, line:sub(1, 50)),
          vim.log.levels.WARN
        )
      end
    end
  end
  
  return commits, nil
end

-- Parse commits with the default revset (all commits)
M.parse_all_commits = function(options)
  return M.parse_commits('all()', options)
end

-- Parse commits for a specific revset query
M.parse_revset = function(revset, options)
  return M.parse_commits(revset, options)
end

-- Get commit data for the current working copy
M.parse_current_commit = function()
  return M.parse_commits('@', { limit = 1 })
end

-- Refresh commit data (for auto-refresh after operations)
M.refresh = function(current_revset, options)
  return M.parse_commits(current_revset or 'all()', options)
end

-- Test function to validate template parsing
M.test_template = function()
  local commits, err = M.parse_commits('all()', { limit = 5 })
  if err then
    vim.notify("Template test failed: " .. err, vim.log.levels.ERROR)
    return false
  end
  
  if not commits or #commits == 0 then
    vim.notify("Template test returned no commits", vim.log.levels.WARN)
    return false
  end
  
  local commit = commits[1]
  vim.notify(
    string.format("Template test successful. First commit: %s (%s)", 
                  commit.short_change_id, commit:get_author_display()),
    vim.log.levels.INFO
  )
  return true
end

return M