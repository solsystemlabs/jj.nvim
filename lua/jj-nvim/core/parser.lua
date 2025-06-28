local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_module = require('jj-nvim.core.commit')
local ansi = require('jj-nvim.utils.ansi')

-- Template to extract commit data using jj's template syntax
-- Each field is separated by Unit Separator character (\x1F), with record separator between commits
local FIELD_SEP = "\x1F"  -- Unit Separator (guaranteed not to appear in commit messages)
local RECORD_SEP = "\x1E" -- Record Separator (for commit boundaries)
local COMMIT_TEMPLATE =
[[change_id ++ "\x1F" ++ commit_id ++ "\x1F" ++ change_id.short(8) ++ "\x1F" ++ commit_id.short(8) ++ "\x1F" ++ change_id.shortest() ++ "\x1F" ++ commit_id.shortest() ++ "\x1F" ++ author.name() ++ "\x1F" ++ author.email() ++ "\x1F" ++ author.timestamp() ++ "\x1F" ++ description.first_line() ++ "\x1F" ++ description ++ "\x1F" ++ if(current_working_copy, "true", "false") ++ "\x1F" ++ if(empty, "true", "false") ++ "\x1F" ++ if(mine, "true", "false") ++ "\x1F" ++ if(root, "true", "false") ++ "\x1F" ++ if(conflict, "true", "false") ++ "\x1F" ++ bookmarks.join(",") ++ "\x1F" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\x1E\n"]]



-- Helper function to parse template data into lookup map
local function parse_template_data(data_output)
  local commit_data_by_id = {}

  local commit_blocks = vim.split(data_output, RECORD_SEP, { plain = true })
  
  for _, commit_block in ipairs(commit_blocks) do
    local trimmed_block = commit_block:match("^%s*(.-)%s*$") -- trim whitespace

    if trimmed_block ~= "" then
      local parts = vim.split(trimmed_block, FIELD_SEP, { plain = true })

      if #parts >= 18 then
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
          full_description = parts[11] or "",
          current_working_copy = parts[12] == "true",
          empty = parts[13] == "true",
          mine = parts[14] == "true",
          root = parts[15] == "true",
          conflict = parts[16] == "true",
          bookmarks = parts[17] ~= "" and vim.split(parts[17], ',', { plain = true }) or {},
          parents = parts[18] ~= "" and vim.split(parts[18], ',', { plain = true }) or {}
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

-- Helper function to extract graph prefix from a description line
local function extract_graph_prefix_from_line(description_line, commit_graph)
  if not description_line or description_line == "" then
    return generate_fallback_description_graph(commit_graph)
  end

  -- Strip ANSI codes for analysis
  local clean_line = ansi.strip_ansi(description_line)
  local clean_commit_graph = ansi.strip_ansi(commit_graph or "")

  -- The description line has the same graph structure as the commit line,
  -- but with description text instead of commit ID
  -- We need to find where the description text starts and extract everything before it

  -- Strategy: Find the rightmost non-graph character position in the commit graph
  -- and use that as a reference point for the description graph
  local commit_graph_length = vim.fn.strchars(clean_commit_graph)

  -- Find where the actual description text starts by looking for text patterns
  -- Description text typically starts after spaces following the graph structure
  local graph_end_pos = 0
  local in_graph_area = true

  for i = 1, vim.fn.strchars(clean_line) do
    local char = vim.fn.strcharpart(clean_line, i - 1, 1)

    if in_graph_area then
      -- We're still in the graph area if we see graph characters or spaces
      if char:match("[│├─╮╯╭┤~%s]") then
        graph_end_pos = i
      else
        -- We've hit non-graph content (description text)
        in_graph_area = false
        break
      end
    end
  end

  -- Extract the graph prefix portion
  local graph_prefix = ""
  if graph_end_pos > 0 then
    graph_prefix = vim.fn.strcharpart(clean_line, 0, graph_end_pos)

    -- Ensure the graph prefix has the same length as the commit graph
    -- by padding with spaces if necessary
    local prefix_length = vim.fn.strchars(graph_prefix)
    if prefix_length < commit_graph_length then
      graph_prefix = graph_prefix .. string.rep(" ", commit_graph_length - prefix_length)
    end
  else
    -- Fallback to generating from commit graph
    return generate_fallback_description_graph(commit_graph)
  end

  -- Add trailing spaces for description area
  if not graph_prefix:match("%s%s$") then
    graph_prefix = graph_prefix .. "  "
  end

  return graph_prefix
end

-- Helper function to parse graph structure from * separator output
local function parse_graph_structure(graph_output)
  local graph_lines = vim.split(graph_output, '\n', { plain = true })
  local entries = {} -- Now contains both commits and elided sections
  local current_entry = nil
  local current_elided = nil
  local state =
  "looking_for_commit" -- "looking_for_commit", "expecting_description", "collecting_connectors", "collecting_elided"

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
      -- Extract just the graph prefix from the description line
      current_entry.description_graph = extract_graph_prefix_from_line(line, current_entry.commit_graph)
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
        -- Check if this connector line should be standalone for graph flow continuity
        local clean_line = ansi.strip_ansi(line)
        local has_complex_connectors = clean_line:match("╭") or clean_line:match("╰") or clean_line:match("├") or
            clean_line:match("┤")

        if has_complex_connectors then
          -- Complex connector lines should be standalone to maintain graph flow
          table.insert(entries, current_entry)
          current_entry = nil

          -- Create standalone connector entry
          local standalone_connector = {
            type = "connector",
            lines = { line }
          }
          table.insert(entries, standalone_connector)
          state = "looking_for_commit"
        else
          -- Simple connector lines can be added to current commit
          table.insert(current_entry.connector_lines, line)
        end
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

  -- Find the position of the commit symbol (rightmost symbol)
  local commit_symbol_pos = nil
  local commit_symbols = { "@", "○", "◆", "×" }

  for i = char_count - 1, 0, -1 do
    local char = vim.fn.strcharpart(clean_graph, i, 1)
    for _, sym in ipairs(commit_symbols) do
      if char == sym then
        commit_symbol_pos = i
        break
      end
    end
    if commit_symbol_pos then break end
  end

  -- Build the description graph prefix
  for i = 0, char_count - 1 do
    local char = vim.fn.strcharpart(clean_graph, i, 1)

    if char == " " then
      result = result .. " "
    elseif char == "│" then
      result = result .. "│"
    elseif commit_symbol_pos and i == commit_symbol_pos then
      -- Replace commit symbol with vertical bar to maintain flow
      result = result .. "│"
    elseif char == "─" then
      -- Horizontal lines become spaces in description area
      result = result .. " "
    elseif char:match("[├┤╭╰╮╯]") then
      -- Complex connectors become vertical bars to maintain column flow
      result = result .. "│"
    else
      -- Any other symbol becomes vertical bar
      result = result .. "│"
    end
  end

  -- Ensure we have proper spacing after the graph
  if not result:match("%s$") then
    result = result .. "  "
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
    elseif graph_entry.type == "connector" then
      -- Create standalone connector entry
      local connector_entry = {
        type = "connector",
        lines = graph_entry.lines,
        line_start = nil, -- Will be set during rendering
        line_end = nil    -- Will be set during rendering
      }
      table.insert(result, connector_entry)
    elseif graph_entry.type == "commit" then
      local template_data = commit_data_by_id[graph_entry.commit_id]

      if template_data then
        local commit = commit_module.from_template_data(template_data)

        -- Add graph structure from Phase 1
        commit.complete_graph = graph_entry.commit_graph
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
