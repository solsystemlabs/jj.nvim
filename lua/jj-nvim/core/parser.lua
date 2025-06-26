local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_module = require('jj-nvim.core.commit')
local ansi = require('jj-nvim.utils.ansi')

-- Template to extract commit data using jj's template syntax
-- Each field is separated by | delimiter, with explicit newlines between commits
local COMMIT_TEMPLATE =
[[change_id ++ "|" ++ commit_id ++ "|" ++ change_id.short(8) ++ "|" ++ commit_id.short(8) ++ "|" ++ change_id.shortest() ++ "|" ++ commit_id.shortest() ++ "|" ++ author.name() ++ "|" ++ author.email() ++ "|" ++ author.timestamp() ++ "|" ++ description.first_line() ++ "|" ++ if(current_working_copy, "true", "false") ++ "|" ++ if(empty, "true", "false") ++ "|" ++ if(mine, "true", "false") ++ "|" ++ if(root, "true", "false") ++ "|" ++ if(conflict, "true", "false") ++ "|" ++ bookmarks.join(",") ++ "|" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\n"]]


-- Helper function to parse template data into lookup map
local function parse_template_data(data_output)
  local commit_data_by_id = {}

  for line in data_output:gmatch('[^\r\n]+') do
    line = line:match("^%s*(.-)%s*$") -- trim whitespace

    if line ~= "" then
      local parts = vim.split(line, '|', { plain = true })

      if #parts >= 17 then
        local commit_data = {
          change_id = parts[1] or "",
          commit_id = parts[2] or "",
          short_change_id = parts[3] or "",
          short_commit_id = parts[4] or "",
          shortest_change_id = parts[5] or "",
          shortest_commit_id = parts[6] or "",
          author = {
            name = parts[7] or "",
            email = parts[8] or "",
            timestamp = parts[9] or ""
          },
          description = parts[10] or "",
          current_working_copy = parts[11] == "true",
          empty = parts[12] == "true",
          mine = parts[13] == "true",
          root = parts[14] == "true",
          conflict = parts[15] == "true",
          bookmarks = parts[16] ~= "" and vim.split(parts[16], ',', { plain = true }) or {},
          parents = parts[17] ~= "" and vim.split(parts[17], ',', { plain = true }) or {}
        }

        commit_data_by_id[commit_data.short_commit_id] = commit_data
      end
    end
  end

  return commit_data_by_id
end

-- Helper function to check if a line represents elided revisions
local function is_elided_line(line)
  local clean_line = ansi.strip_ansi(line)
  -- Only match lines that contain "(elided revisions)" text or start with ~ (not preceded by graph chars)
  return clean_line:match("%(elided revisions%)") or clean_line:match("^~")
end

-- Helper function to check if a line contains ~ symbol (indicating approach to elided section)
local function has_tilde_symbol(line)
  local clean_line = ansi.strip_ansi(line)
  return clean_line:match("~") ~= nil
end

-- Helper function to check if there's an elided section coming up in the next few lines
local function has_elided_section_ahead(graph_lines, current_index)
  -- Look ahead up to 5 lines to see if we'll encounter an elided section
  for i = current_index + 1, math.min(current_index + 5, #graph_lines) do
    local line = graph_lines[i]
    if line and (is_elided_line(line) or has_tilde_symbol(line)) then
      return true
    end
    -- Stop looking if we hit a commit line
    if line and line:find("*", 1, true) then
      return false
    end
  end
  return false
end

-- Helper function to parse graph structure from * separator output
local function parse_graph_structure(graph_output)
  local graph_lines = vim.split(graph_output, '\n', { plain = true })
  local entries = {} -- Now contains both commits and elided sections
  local current_entry = nil
  local current_elided = nil
  local state = "looking_for_commit" -- "looking_for_commit", "expecting_description", "collecting_connectors", "collecting_elided"

  for line_index, line in ipairs(graph_lines) do
    if line:match("^%s*$") and state ~= "collecting_elided" then
      -- Skip empty lines unless we're collecting elided content
      goto continue
    end

    if line:find("*", 1, true) then
      -- COMMIT LINE: Save previous entries, start new commit
      if current_elided then
        table.insert(entries, current_elided)
        current_elided = nil
      end
      if current_entry then
        table.insert(entries, current_entry)
      end

      local star_pos = line:find("*", 1, true)
      local commit_graph = line:sub(1, star_pos - 1)
      local commit_id_raw = line:sub(star_pos + 1):match("^%s*(.-)%s*$")
      local commit_id = ansi.strip_ansi(commit_id_raw)

      current_entry = {
        type = "commit",
        commit_id = commit_id,
        commit_graph = commit_graph,
        description_graph = nil, -- Will be set by next non-* line
        connector_lines = {}
      }
      state = "expecting_description"
    elseif is_elided_line(line) and state == "collecting_connectors" then
      -- ELIDED LINE: Start elided section, but first save current commit
      table.insert(entries, current_entry)
      current_entry = nil
      
      current_elided = {
        type = "elided",
        lines = { line } -- Start with the elided line
      }
      state = "collecting_elided"
    elseif state == "expecting_description" then
      -- DESCRIPTION LINE: First non-* line after commit
      current_entry.description_graph = line
      state = "collecting_connectors"
    elseif state == "collecting_connectors" then
      -- CONNECTOR LINES: Check if this starts an elided section or leads to one
      if has_tilde_symbol(line) or has_elided_section_ahead(graph_lines, line_index) then
        -- This connector line starts or precedes an elided section
        table.insert(entries, current_entry)
        current_entry = nil
        
        current_elided = {
          type = "elided",
          lines = { line } -- Start with this connector line
        }
        state = "collecting_elided"
      else
        -- Normal connector line
        table.insert(current_entry.connector_lines, line)
      end
    elseif state == "collecting_elided" then
      -- Continue collecting elided lines or transition back to looking for commits
      if is_elided_line(line) or line:match("^%s*$") or line:match("^[│%s]*$") then
        -- Include elided lines, empty lines, and connector lines in elided section
        table.insert(current_elided.lines, line)
      elseif line:find("*", 1, true) then
        -- Commit line encountered, save elided section and start new commit
        table.insert(entries, current_elided)
        current_elided = nil
        
        local star_pos = line:find("*", 1, true)
        local commit_graph = line:sub(1, star_pos - 1)
        local commit_id_raw = line:sub(star_pos + 1):match("^%s*(.-)%s*$")
        local commit_id = ansi.strip_ansi(commit_id_raw)

        current_entry = {
          type = "commit",
          commit_id = commit_id,
          commit_graph = commit_graph,
          description_graph = nil,
          connector_lines = {}
        }
        state = "expecting_description"
      else
        -- Other line types, continue collecting as elided for now
        table.insert(current_elided.lines, line)
      end
    elseif is_elided_line(line) then
      -- Handle elided lines that appear in unexpected states
      if current_entry then
        table.insert(entries, current_entry)
        current_entry = nil
      end
      
      current_elided = {
        type = "elided",
        lines = { line }
      }
      state = "collecting_elided"
    end

    ::continue::
  end

  -- Save any remaining entries
  if current_elided then
    table.insert(entries, current_elided)
  end
  if current_entry then
    table.insert(entries, current_entry)
  end

  return entries
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
  local result = {} -- Contains both commits and elided sections

  for _, graph_entry in ipairs(graph_entries) do
    if graph_entry.type == "elided" then
      -- Create elided section entry
      local elided_entry = {
        type = "elided",
        lines = graph_entry.lines,
        line_start = nil, -- Will be set during rendering
        line_end = nil    -- Will be set during rendering
      }
      table.insert(result, elided_entry)
    elseif graph_entry.type == "commit" then
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

        table.insert(result, commit)
      else
        -- Commit ID not found in template data
        if graph_entry.commit_id then
          vim.notify("Warning: Commit " .. graph_entry.commit_id .. " not found in template data", vim.log.levels.WARN)
        end
      end
    end
  end

  return result
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
  local mixed_entries = merge_graph_and_template_data(graph_entries, commit_data_by_id)

  return mixed_entries, nil
end

-- Parse all commits using separate graph approach
M.parse_all_commits_with_separate_graph = function(options)
  return M.parse_commits_with_separate_graph('all()', options)
end

return M
