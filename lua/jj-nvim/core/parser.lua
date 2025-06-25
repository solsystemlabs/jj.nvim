local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_module = require('jj-nvim.core.commit')

-- Template to extract commit data using jj's template syntax
-- Each field is separated by | delimiter, with explicit newlines between commits
local COMMIT_TEMPLATE = [[change_id ++ "|" ++ commit_id ++ "|" ++ change_id.short(8) ++ "|" ++ commit_id.short(8) ++ "|" ++ author.name() ++ "|" ++ author.email() ++ "|" ++ author.timestamp() ++ "|" ++ description.first_line() ++ "|" ++ if(current_working_copy, "true", "false") ++ "|" ++ if(empty, "true", "false") ++ "|" ++ if(mine, "true", "false") ++ "|" ++ if(root, "true", "false") ++ "|" ++ bookmarks.join(",") ++ "|" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\n"]]

-- Parse commits using default jj log output with graph
M.parse_commits_with_graph = function(revset, options)
  options = options or {}
  local limit = options.limit or 100
  
  -- Build jj log command that includes the graph
  local args = {
    'log',
    '--no-pager',
    '-r', revset or 'all()',
    '--limit', tostring(limit)
  }
  
  -- Execute the command
  local stdout, err = commands.execute(args, { silent = true })
  if not stdout then
    return nil, err or "Failed to execute jj log command"
  end
  
  -- Return the raw output for now - we'll parse the graph structure later
  return stdout, nil
end

-- Parse commits using jj template system (legacy method)
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

-- Parse commits with graph structure (returns raw jj log output)
M.parse_all_commits_with_graph = function(options)
  return M.parse_commits_with_graph('all()', options)
end

-- Parse commits from jj log output including graph structure
M.parse_commits_from_log = function(revset, options)
  options = options or {}
  local limit = options.limit or 100
  
  -- Get raw jj log output with graph
  local args = {
    'log',
    '--no-pager',
    '-r', revset or 'all()',
    '--limit', tostring(limit)
  }
  
  local stdout, err = commands.execute(args, { silent = true })
  if not stdout then
    return nil, err or "Failed to execute jj log command"
  end
  
  local lines = vim.split(stdout, '\n', { plain = true })
  local commits = {}
  local current_commit = nil
  
  for line_num, line in ipairs(lines) do
    if line:match("^%s*$") then
      -- Skip empty lines
      goto continue
    end
    
    -- Check if this is a commit header line (contains commit symbols)
    -- Try to match each symbol pattern individually due to Unicode issues
    local graph_prefix, symbol, commit_content
    
    -- Try @ symbol first
    graph_prefix, symbol, commit_content = line:match("^([│├─╮╯╭┤~%s]*)(@)%s+(.*)$")
    if not symbol then
      -- Try ○ symbol 
      graph_prefix, symbol, commit_content = line:match("^([│├─╮╯╭┤~%s]*)(○)%s+(.*)$")
    end
    if not symbol then
      -- Try ◆ symbol
      graph_prefix, symbol, commit_content = line:match("^([│├─╮╯╭┤~%s]*)(◆)%s+(.*)$")
    end
    if not symbol then
      -- Try × symbol
      graph_prefix, symbol, commit_content = line:match("^([│├─╮╯╭┤~%s]*)(×)%s+(.*)$")
    end
    
    if symbol and commit_content then
      -- This is a commit header line
      if current_commit then
        -- Save previous commit
        table.insert(commits, current_commit)
      end
      
      -- Parse commit content (author, timestamp, commit_id, etc.)
      current_commit = M.parse_commit_header_line(commit_content, graph_prefix, symbol)
      
    elseif current_commit then
      -- This is a description, bookmark, or connector line
      local line_graph_prefix = line:match("^([│├─╮╯╭┤~%s]*)")
      local line_content = line:sub(#line_graph_prefix + 1)
      
      -- Add to current commit's additional lines
      if not current_commit.additional_lines then
        current_commit.additional_lines = {}
      end
      table.insert(current_commit.additional_lines, {
        graph_prefix = line_graph_prefix,
        content = line_content
      })
    end
    
    ::continue::
  end
  
  -- Don't forget the last commit
  if current_commit then
    table.insert(commits, current_commit)
  end
  
  
  return commits, nil
end

-- Helper function to parse commit header line content
M.parse_commit_header_line = function(content, graph_prefix, symbol)
  -- Parse a line like: "zvsptuoz teernisse@visiostack.com 2025-06-25 13:43:56 d709b014"
  -- This is a simplified parser - we'll need to make it more robust
  
  local parts = vim.split(content, ' ', { plain = true })
  if #parts < 4 then
    return nil
  end
  
  local commit = {
    graph_prefix = graph_prefix or "",
    symbol = symbol,
    short_change_id = parts[1],
    change_id = parts[1], -- We don't have full change_id from default output
    author = {
      email = parts[2],
      name = parts[2]:match("^([^@]+)") or parts[2],
      timestamp = table.concat(parts, " ", 3, 4) -- Date and time
    },
    short_commit_id = parts[#parts],
    commit_id = parts[#parts],
    current_working_copy = symbol == "@",
    root = symbol == "◆",
    conflict = symbol == "×",
    description = "",
    empty = false,
    mine = true,
    bookmarks = {},
    parents = {},
    additional_lines = {}
  }
  
  return commit_module.from_template_data(commit)
end

-- Parse commits using separate graph and data commands (new approach)
M.parse_commits_with_separate_graph = function(revset, options)
  options = options or {}
  local limit = options.limit or 100
  
  -- First command: Get pure graph structure
  local graph_args = {
    'log',
    '-T', '""',
    '--no-pager',
    '-r', revset or 'all()',
    '--limit', tostring(limit)
  }
  
  local graph_output, graph_err = commands.execute(graph_args, { silent = true })
  if not graph_output then
    return nil, graph_err or "Failed to get graph structure"
  end
  
  -- Second command: Get structured commit data
  local data_args = {
    'log',
    '--template', COMMIT_TEMPLATE,
    '--no-graph',
    '--no-pager',
    '-r', revset or 'all()',
    '--limit', tostring(limit)
  }
  
  local data_output, data_err = commands.execute(data_args, { silent = true })
  if not data_output then
    return nil, data_err or "Failed to get commit data"
  end
  
  -- Parse commit data using existing template parser
  local template_commits = {}
  local line_num = 0
  
  for line in data_output:gmatch('[^\r\n]+') do
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
        table.insert(template_commits, commit)
      end
    end
  end
  
  -- Process graph structure and map to commits
  local graph_lines = vim.split(graph_output, '\n', { plain = true })
  local commits = {}
  local commit_index = 1
  local current_commit = nil
  
  for _, graph_line in ipairs(graph_lines) do
    if graph_line:match("^%s*$") then
      -- Skip empty lines
      goto continue
    end
    
    -- Check if this line contains a node symbol (@ ○ ◆ ×)
    local has_at = graph_line:find("@")
    local has_circle = graph_line:find("○")  
    local has_diamond = graph_line:find("◆")
    local has_cross = graph_line:find("×")
    local has_node_symbol = has_at or has_circle or has_diamond or has_cross
    
    if has_node_symbol then
      -- This is a commit line - map to next template commit
      if commit_index <= #template_commits then
        current_commit = template_commits[commit_index]
        
        -- Extract graph prefix and symbol from the graph line
        local symbol = has_at and "@" or has_circle and "○" or has_diamond and "◆" or "×"
        local symbol_pos = has_at and graph_line:find("@") or 
                          has_circle and graph_line:find("○") or 
                          has_diamond and graph_line:find("◆") or 
                          graph_line:find("×")
        
        current_commit.graph_prefix = graph_line:sub(1, symbol_pos - 1)
        current_commit.symbol = symbol
        current_commit.additional_lines = {}
        
        table.insert(commits, current_commit)
        commit_index = commit_index + 1
      end
    else
      -- This is a connector line - attach to current commit
      if current_commit then
        table.insert(current_commit.additional_lines, {
          graph_prefix = graph_line,
          content = ""
        })
      end
    end
    
    ::continue::
  end
  
  return commits, nil
end

-- Parse all commits using separate graph approach
M.parse_all_commits_with_separate_graph = function(options)
  return M.parse_commits_with_separate_graph('all()', options)
end

-- Parse all commits from jj log output with graph structure (legacy)
M.parse_all_commits_from_log = function(options)
  return M.parse_commits_from_log('all()', options)
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