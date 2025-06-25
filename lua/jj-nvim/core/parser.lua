local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_module = require('jj-nvim.core.commit')
local ansi = require('jj-nvim.utils.ansi')

-- Template to extract commit data using jj's template syntax
-- Each field is separated by | delimiter, with explicit newlines between commits
local COMMIT_TEMPLATE =
[[change_id ++ "|" ++ commit_id ++ "|" ++ change_id.short(8) ++ "|" ++ commit_id.short(8) ++ "|" ++ author.name() ++ "|" ++ author.email() ++ "|" ++ author.timestamp() ++ "|" ++ description.first_line() ++ "|" ++ if(current_working_copy, "true", "false") ++ "|" ++ if(empty, "true", "false") ++ "|" ++ if(mine, "true", "false") ++ "|" ++ if(root, "true", "false") ++ "|" ++ bookmarks.join(",") ++ "|" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\n"]]


-- Helper function to parse template data into lookup map
local function parse_template_data(data_output)
  local commit_data_by_id = {}

  for line in data_output:gmatch('[^\r\n]+') do
    line = line:match("^%s*(.-)%s*$") -- trim whitespace

    if line ~= "" then
      local parts = vim.split(line, '|', { plain = true })

      if #parts >= 14 then
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

        commit_data_by_id[commit_data.short_commit_id] = commit_data
      end
    end
  end

  return commit_data_by_id
end

-- Helper function to parse graph structure from * separator output
local function parse_graph_structure(graph_output)
  local graph_lines = vim.split(graph_output, '\n', { plain = true })
  local commit_entries = {}
  local current_entry = nil
  local state = "looking_for_commit" -- "looking_for_commit", "expecting_description", "collecting_connectors"

  for _, line in ipairs(graph_lines) do
    if line:match("^%s*$") then
      -- Skip empty lines
      goto continue
    end

    if line:find("*", 1, true) then
      -- COMMIT LINE: Save previous entry, start new one
      if current_entry then
        table.insert(commit_entries, current_entry)
      end

      local star_pos = line:find("*", 1, true)
      local commit_graph = line:sub(1, star_pos - 1)
      local commit_id_raw = line:sub(star_pos + 1):match("^%s*(.-)%s*$")
      local commit_id = ansi.strip_ansi(commit_id_raw)

      current_entry = {
        commit_id = commit_id,
        commit_graph = commit_graph,
        description_graph = nil, -- Will be set by next non-* line
        connector_lines = {}
      }
      state = "expecting_description"
    elseif state == "expecting_description" then
      -- DESCRIPTION LINE: First non-* line after commit
      current_entry.description_graph = line
      state = "collecting_connectors"
    elseif state == "collecting_connectors" then
      -- CONNECTOR LINES: Subsequent non-* lines
      table.insert(current_entry.connector_lines, line)
    end

    ::continue::
  end

  -- Don't forget last entry
  if current_entry then
    table.insert(commit_entries, current_entry)
  end

  return commit_entries
end

-- Helper function to generate fallback description graph from commit graph
local function generate_fallback_description_graph(commit_graph)
  if not commit_graph or commit_graph == "" then
    return "│  " -- Default fallback
  end

  -- Strip ANSI codes to get clean structure for analysis
  local clean_graph = ansi.strip_ansi(commit_graph)
  local result = ""
  local char_count = vim.fn.strchars(clean_graph)
  for i = 0, char_count - 1 do
    local char = vim.fn.strcharpart(clean_graph, i, 1)
    if char == " " then
      result = result .. " "
    else
      result = result .. "│" -- Replace any graph symbol with │
    end
  end
  return result
end

-- Helper function to find rightmost symbol in graph structure
local function find_rightmost_symbol(graph_part)
  if not graph_part or graph_part == "" then
    return nil, nil
  end

  -- Work with clean graph for symbol detection
  local clean_graph = ansi.strip_ansi(graph_part)
  local symbols = { "@", "○", "◆", "×" }
  local symbol = nil
  local symbol_pos = nil

  -- Find the rightmost symbol (the actual commit symbol)
  for i = #clean_graph, 1, -1 do
    local char = clean_graph:sub(i, i)
    for _, sym in ipairs(symbols) do
      if char == sym then
        symbol = sym
        symbol_pos = i
        break
      end
    end
    if symbol then break end
  end

  return symbol, symbol_pos
end

-- Helper function to merge graph structure with template data
local function merge_graph_and_template_data(graph_entries, commit_data_by_id)
  local commits = {}

  for _, graph_entry in ipairs(graph_entries) do
    local template_data = commit_data_by_id[graph_entry.commit_id]

    if template_data then
      local commit = commit_module.from_template_data(template_data)

      -- Add graph structure from Phase 1
      commit.complete_graph = graph_entry.commit_graph
      if graph_entry.description_graph then
        graph_entry.description_graph = graph_entry.description_graph .. "  "
      end
      commit.description_graph = graph_entry.description_graph or
          generate_fallback_description_graph(graph_entry.commit_graph)

      -- Parse commit graph components
      local symbol, symbol_pos = find_rightmost_symbol(graph_entry.commit_graph)
      if symbol and symbol_pos then
        commit.graph_prefix = graph_entry.commit_graph:sub(1, symbol_pos - 1)
        commit.symbol = symbol
        commit.graph_suffix = graph_entry.commit_graph:sub(symbol_pos + 1)
      else
        -- Fallback if no symbol found
        commit.graph_prefix = ""
        commit.symbol = "○"
        commit.graph_suffix = ""
      end

      -- Store connector lines
      commit.additional_lines = {}
      for _, connector_line in ipairs(graph_entry.connector_lines) do
        table.insert(commit.additional_lines, {
          graph_prefix = connector_line,
          content = "",
          type = "connector"
        })
      end

      table.insert(commits, commit)
    else
      -- Commit ID not found in template data
      if graph_entry.commit_id then
        vim.notify("Warning: Commit " .. graph_entry.commit_id .. " not found in template data", vim.log.levels.WARN)
      end
    end
  end

  return commits
end

-- Helper function to build jj command args with optional revset
local function build_jj_args(base_args, revset, limit)
  local args = {}
  for _, arg in ipairs(base_args) do
    table.insert(args, arg)
  end

  table.insert(args, '--limit')
  table.insert(args, tostring(limit))
  table.insert(args, '--no-pager')

  if revset and revset ~= 'all()' then
    table.insert(args, '-r')
    table.insert(args, revset)
  end

  return args
end

-- Parse commits using separate graph and data commands with commit ID matching
M.parse_commits_with_separate_graph = function(revset, options)
  options = options or {}
  local limit = options.limit or 100

  -- Get graph with commit IDs using * separator
  local graph_args = build_jj_args({ 'log', '--template', '"*" ++ commit_id.short(8)' }, revset, limit)
  local graph_output, graph_err = commands.execute(graph_args, { silent = true })
  if not graph_output then
    return nil, graph_err or "Failed to get graph output"
  end

  -- Get structured commit data
  local data_args = build_jj_args({ 'log', '--template', COMMIT_TEMPLATE, '--no-graph' }, revset, limit)
  local data_output, data_err = commands.execute(data_args, { silent = true })
  if not data_output then
    return nil, data_err or "Failed to get commit data"
  end

  local commit_data_by_id = parse_template_data(data_output)

  -- Phase 1: Parse graph structure using new state machine approach
  local graph_entries = parse_graph_structure(graph_output)

  -- Phase 3: Merge graph structure with template data
  local commits = merge_graph_and_template_data(graph_entries, commit_data_by_id)

  return commits, nil
end

-- Parse all commits using separate graph approach
M.parse_all_commits_with_separate_graph = function(options)
  return M.parse_commits_with_separate_graph('all()', options)
end

return M
