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

-- Colored template with field markers for color extraction
-- Each field is wrapped with unique markers to identify where colors should be extracted from
local COLORED_TEMPLATE =
[["CHID_START" ++ change_id.short(8) ++ "CHID_END \x1F CID_START" ++ commit_id.short(8) ++ "CID_END \x1F AUTH_START" ++ author.email() ++ "AUTH_END \x1F TIME_START" ++ author.timestamp() ++ "TIME_END \x1F DESC_START" ++ description.first_line() ++ "DESC_END \x1F BOOK_START" ++ bookmarks.join(",") ++ "BOOK_END \x1F" ++ if(current_working_copy, "true", "false") ++ "\x1F" ++ if(empty, "true", "false") ++ "\x1F" ++ if(mine, "true", "false") ++ "\x1F" ++ if(root, "true", "false") ++ "\x1F" ++ if(conflict, "true", "false") ++ "\x1F" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\x1E\n"]]


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

-- Helper function to parse colored template data and extract both text and color information
local function parse_colored_template_data(colored_output)
  local commit_data_by_id = {}

  local commit_blocks = vim.split(colored_output, RECORD_SEP, { plain = true })
  
  for _, commit_block in ipairs(commit_blocks) do
    local trimmed_block = commit_block:match("^%s*(.-)%s*$") -- trim whitespace

    if trimmed_block ~= "" then
      local parts = vim.split(trimmed_block, FIELD_SEP, { plain = true })

      if #parts >= 12 then
        -- Extract colors and text for each field
        local change_id_color, change_id_text = ansi.extract_field_colors(parts[1] or "", "CHID_START", "CHID_END")
        local commit_id_color, commit_id_text = ansi.extract_field_colors(parts[2] or "", "CID_START", "CID_END")
        local author_color, author_text = ansi.extract_field_colors(parts[3] or "", "AUTH_START", "AUTH_END")
        local timestamp_color, timestamp_text = ansi.extract_field_colors(parts[4] or "", "TIME_START", "TIME_END")
        local description_color, description_text = ansi.extract_field_colors(parts[5] or "", "DESC_START", "DESC_END")
        local bookmarks_color, bookmarks_text = ansi.extract_field_colors(parts[6] or "", "BOOK_START", "BOOK_END")
        
        local commit_data = {
          change_id = "",  -- We'll get this from the regular template
          commit_id = "",  -- We'll get this from the regular template
          short_change_id = change_id_text,
          short_commit_id = commit_id_text,
          shortest_change_id = "", -- We'll get this from the regular template
          shortest_commit_id = "", -- We'll get this from the regular template
          author = {
            name = "",
            email = author_text,
            timestamp = timestamp_text
          },
          description = description_text,
          full_description = description_text, -- We'll get the full version from regular template
          current_working_copy = (parts[7] or "") == "true",
          empty = (parts[8] or "") == "true",
          mine = (parts[9] or "") == "true",
          root = (parts[10] or "") == "true",
          conflict = (parts[11] or "") == "true",
          bookmarks = bookmarks_text ~= "" and vim.split(bookmarks_text, ',', { plain = true }) or {},
          parents = (parts[12] or "") ~= "" and vim.split(parts[12], ',', { plain = true }) or {},
          colors = {
            change_id = change_id_color,
            commit_id = commit_id_color,
            author = author_color,
            timestamp = timestamp_color,
            description = description_color,
            bookmarks = bookmarks_color,
            graph = "",            -- Will be extracted from graph output
            empty_indicator = "",  -- Will be extracted if needed
            conflict_indicator = "" -- Will be extracted if needed
          }
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

-- Helper function to merge regular template data with colored template data
local function merge_template_data(regular_data, colored_data)
  local merged_data = {}
  
  for commit_id, regular_commit in pairs(regular_data) do
    local colored_commit = colored_data[commit_id]
    
    if colored_commit then
      -- Start with regular data and add color information
      merged_data[commit_id] = vim.tbl_deep_extend("force", regular_commit, {
        colors = colored_commit.colors
      })
    else
      -- No color data available, use regular data with empty colors
      merged_data[commit_id] = regular_commit
    end
  end
  
  return merged_data
end

-- Simple deep copy function for older Neovim compatibility
local function deep_copy(t)
  if type(t) ~= 'table' then return t end
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = deep_copy(v)
  end
  return copy
end

-- Find the colored segment at a specific position in the original colored text
local function find_colored_segment_at_position(colored_text, start_pos, end_pos)
  -- This is complex because ANSI codes shift positions
  -- We need to map clean text positions to colored text positions
  
  local clean_pos = 1
  local colored_pos = 1
  local segment_start_colored = nil
  local segment_end_colored = nil
  
  while colored_pos <= #colored_text and clean_pos <= #ansi.strip_ansi(colored_text) do
    -- Check if we're at an ANSI escape sequence
    local esc_start, esc_end = colored_text:find('\27%[[%d;]*m', colored_pos)
    
    if esc_start and esc_start == colored_pos then
      -- Skip ANSI sequence in colored text, don't advance clean position
      colored_pos = esc_end + 1
    else
      -- Regular character
      if clean_pos == start_pos then
        segment_start_colored = colored_pos
      end
      if clean_pos == end_pos then
        segment_end_colored = colored_pos
        break
      end
      
      clean_pos = clean_pos + 1
      colored_pos = colored_pos + 1
    end
  end
  
  if segment_start_colored and segment_end_colored then
    return colored_text:sub(segment_start_colored, segment_end_colored)
  elseif segment_start_colored then
    -- Find the end by looking for the next field or end of line
    local remaining = colored_text:sub(segment_start_colored)
    local next_field_pos = remaining:find(" [%w%(]") -- Look for space followed by word char or (
    if next_field_pos then
      return remaining:sub(1, next_field_pos - 1)
    else
      return remaining
    end
  end
  
  return nil
end

-- Extract field colors from a single log line by pattern matching
local function extract_field_colors_from_log_line(colored_line, commit_data)
  local colors = {}
  local clean_line = ansi.strip_ansi(colored_line)
  
  -- Helper function to find a field's position and extract its color
  local function extract_field_color(field_text, field_name)
    if not field_text or field_text == "" then
      return
    end
    
    local start_pos, end_pos = clean_line:find(field_text, 1, true)
    if start_pos then
      -- Find the colored version of this text in the original line
      local colored_segment = find_colored_segment_at_position(colored_line, start_pos, end_pos)
      if colored_segment then
        local field_color = ansi.get_opening_color_codes(colored_segment)
        if field_color and field_color ~= "" then
          colors[field_name] = field_color
        end
      end
    end
  end
  
  -- Extract colors for each field we care about
  extract_field_color(commit_data.short_change_id, "change_id")
  extract_field_color(commit_data.short_commit_id, "commit_id")
  extract_field_color(commit_data.author.email, "author")
  
  -- For timestamp, try to match the format in the actual log output
  if commit_data.author.timestamp then
    -- Try both the full timestamp and the YYYY-MM-DD HH:MM:SS format
    local timestamp_display = commit_data.author.timestamp:match("^([^%.]+)")
    if timestamp_display then
      timestamp_display = timestamp_display:gsub("%.%d+ [+-]%d+:%d+$", "") -- Remove fractional seconds and timezone
      extract_field_color(timestamp_display, "timestamp")
    end
  end
  
  -- For description, look for common patterns
  if commit_data.description and commit_data.description ~= "" then
    extract_field_color(commit_data.description, "description")
  else
    extract_field_color("(no description set)", "description")
  end
  
  -- For bookmarks
  if commit_data.bookmarks and #commit_data.bookmarks > 0 then
    local bookmarks_str = table.concat(commit_data.bookmarks, " ")
    extract_field_color(bookmarks_str, "bookmarks")
  end
  
  return colors
end

-- Extract colors from jj's default format output by matching to structured data
local function extract_colors_from_default_format(colored_log_output, commit_data_by_id)
  local enhanced_data = deep_copy(commit_data_by_id)
  
  -- Split into lines
  local lines = vim.split(colored_log_output, '\n', { plain = true })
  
  for _, line in ipairs(lines) do
    if line and line:find("%S") then -- Skip empty lines
      -- Extract the commit ID from this line to match it to our data
      local clean_line = ansi.strip_ansi(line)
      
      -- Try to find a commit ID pattern in the clean line
      -- Look for 8-character hex patterns that match our known commit IDs
      for commit_id, commit_data in pairs(enhanced_data) do
        if clean_line:find(commit_id, 1, true) then
          -- Found a matching commit, extract colors from this line
          local colors = extract_field_colors_from_log_line(line, commit_data)
          if colors then
            -- Merge the extracted colors into the commit data
            enhanced_data[commit_id].colors = vim.tbl_deep_extend("force", 
              enhanced_data[commit_id].colors or {}, colors)
          end
          break
        end
      end
    end
  end
  
  return enhanced_data
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

        -- Extract graph colors from the colored graph output
        local graph_color = ansi.get_opening_color_codes(graph_entry.commit_graph)
        if graph_color and graph_color ~= "" then
          commit.colors.graph = graph_color
        end

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

  -- Get structured commit data (regular template without colors)
  local data_args = build_jj_args({ 'log', '--template', COMMIT_TEMPLATE, '--no-graph' }, revset, limit)
  local data_output, data_err = commands.execute(data_args, { silent = true })
  if not data_output then
    return nil, data_err or "Failed to get commit data"
  end

  -- Get colored commit data (colored template with colors)
  local colored_args = build_jj_args({ 'log', '--template', COLORED_TEMPLATE, '--no-graph', '--color=always' }, revset, limit)
  local colored_output, colored_err = commands.execute(colored_args, { silent = true })
  
  local commit_data_by_id = parse_template_data(data_output)
  
  -- If we successfully got colored data, merge it with regular data
  if colored_output and not colored_err then
    local colored_data_by_id = parse_colored_template_data(colored_output)
    commit_data_by_id = merge_template_data(commit_data_by_id, colored_data_by_id)
  end

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
