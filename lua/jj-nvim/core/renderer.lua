local M = {}

local config = require('jj-nvim.config')
local ansi = require('jj-nvim.utils.ansi')

-- Rendering mode configuration
local RENDER_MODES = {
  compact = {
    show_description = false,
    show_bookmarks = false,
    single_line = true,
  },
  comfortable = {
    show_description = true,
    show_bookmarks = true,
    single_line = false,
  },
  detailed = {
    show_description = true,
    show_bookmarks = true,
    show_parents = true,
    show_children = false,
    single_line = false,
  }
}

-- Color codes that match jj's output for consistency
local COLORS = {
  current_symbol = '\27[1m\27[38;5;2m', -- @ symbol (bold green)
  regular_symbol = '', -- ○ symbol (no color)
  root_symbol = '\27[1m\27[38;5;14m', -- ◆ symbol (bold bright cyan)
  conflict_symbol = '\27[1m\27[38;5;1m', -- × symbol (bold red)
  change_id_current = '\27[1m\27[38;5;13m', -- Current commit change ID (bold magenta)
  change_id_regular = '\27[1m\27[38;5;5m', -- Regular commit change ID (bold purple)
  change_id_dim = '\27[38;5;8m', -- Dim part of change ID
  author_current = '\27[1m\27[38;5;3m', -- Current commit author (bold yellow)
  author_regular = '\27[38;5;3m', -- Regular commit author (yellow)
  author_root = '\27[38;5;2m', -- Root commit author (dark green)
  timestamp_current = '\27[38;5;14m', -- Current commit timestamp (bright cyan)
  timestamp_regular = '\27[38;5;6m', -- Regular commit timestamp (cyan)
  commit_id_current = '\27[38;5;12m', -- Current commit ID (bright blue)
  commit_id_regular = '\27[1m\27[38;5;4m', -- Regular commit ID (bold blue)
  commit_id_dim = '\27[38;5;8m', -- Dim part of commit ID
  description_current = '\27[1m\27[38;5;3m', -- Current commit "(no description set)" (bold yellow)
  description_regular = '\27[38;5;3m', -- Regular commit "(no description set)" (yellow)
  description_real_current = '\27[1m', -- Current commit real description (bold white)
  description_real_regular = '', -- Regular commit real description (white)
  empty_indicator = '\27[38;5;2m', -- "(empty)" indicator (green)
  bookmarks = '\27[1m\27[38;5;5m', -- Bookmarks (bold purple)
  conflict_indicator = '\27[38;5;1m', -- "conflict" indicator (red)
  branch_symbol = '│', -- Branch continuation symbol
  reset = '\27[0m', -- Reset all formatting
  reset_fg = '\27[39m', -- Reset foreground only
}

-- Helper function to calculate display width of text (accounting for ANSI codes)
local function get_display_width(text)
  if not text or text == "" then
    return 0
  end

  -- Strip ANSI codes and get display width
  local clean_text = ansi.strip_ansi(text)
  return vim.fn.strdisplaywidth(clean_text)
end

-- Helper function to wrap text by words using intelligent wrapping logic
local function wrap_text_by_words(text, graph_prefix, continuation_prefix, window_width)
  if not text or text == "" or not window_width then
    return { graph_prefix .. text }
  end

  -- If the line doesn't exceed window width, no wrapping needed
  local graph_width = get_display_width(graph_prefix)
  local text_width = get_display_width(text)
  if graph_width + text_width <= window_width then
    return { graph_prefix .. text }
  end

  -- Simple word splitting approach - split on spaces from clean text, then reconstruct
  local clean_text = ansi.strip_ansi(text)
  local words = vim.split(clean_text, "%s+", { plain = false })

  -- Apply intelligent wrapping logic similar to main commit line
  local wrapped_lines = {}
  local current_line_words = {}
  local current_width = graph_width
  local continuation_width = get_display_width(continuation_prefix)

  for i, word in ipairs(words) do
    if word ~= "" then -- Skip empty words from multiple spaces
      local word_width = get_display_width(word)
      local space_width = #current_line_words > 0 and 1 or 0

      -- Check if adding this word would exceed window width
      if current_width + space_width + word_width > window_width and #current_line_words > 0 then
        -- Start a new line with this word
        local line_content = table.concat(current_line_words, " ")
        table.insert(wrapped_lines, graph_prefix .. line_content)

        current_line_words = { word }
        current_width = continuation_width + word_width
        graph_prefix = continuation_prefix -- Use continuation prefix for subsequent lines
      else
        -- Add word to current line
        table.insert(current_line_words, word)
        current_width = current_width + space_width + word_width
      end
    end
  end

  -- Add the final line
  if #current_line_words > 0 then
    local line_content = table.concat(current_line_words, " ")
    table.insert(wrapped_lines, graph_prefix .. line_content)
  end

  return wrapped_lines
end

-- Helper function to apply symbol coloring to graph text
local function apply_symbol_colors(graph_text, commit)
  if not graph_text or graph_text == "" then
    return graph_text
  end

  local result = graph_text
  local is_current = commit:is_current()

  -- Apply symbol coloring in order of specificity
  -- Start with conflict symbols (×) - these should always be red regardless of commit type
  result = result:gsub("×", COLORS.conflict_symbol .. "×" .. COLORS.reset)

  -- Then apply commit-specific symbol coloring
  if is_current then
    result = result:gsub("@", COLORS.current_symbol .. "@" .. COLORS.reset_fg)
  end
  if commit.root then
    result = result:gsub("◆", COLORS.root_symbol .. "◆" .. COLORS.reset_fg)
  end

  return result
end

-- Helper function to generate continuation graph from commit graph structure
local function get_continuation_graph_from_commit(source_line)
  if not source_line or source_line == "" then
    return ""
  end

  -- 1. Take the graph content part of the main line
  local clean_line = ansi.strip_ansi(source_line)
  
  -- Extract graph content by finding where description starts
  local graph_content = ""
  local chars = {}
  
  -- Convert to UTF-8 character array
  for char in string.gmatch(clean_line, "[%z\1-\127\194-\244][\128-\191]*") do
    table.insert(chars, char)
  end
  
  -- Find end of graph section
  for _, char in ipairs(chars) do
    if char == " " or char == "│" or char == "@" or char == "○" or char == "◆" or char == "×" or 
       char == "─" or char == "├" or char == "┤" or char == "╭" or char == "╰" or char == "╮" or char == "╯" then
      graph_content = graph_content .. char
    else
      -- Hit description text
      break
    end
  end
  
  -- 2. Count columns, trimming only outer whitespace
  local trimmed_graph = graph_content:gsub("^%s+", ""):gsub("%s+$", "")
  local num_chars = get_display_width(trimmed_graph)
  
  -- 3. Use formula numChars / 2 for '| ' instances, plus single '|' at end, plus '  ' for text indentation
  local pairs_count = math.floor(num_chars / 2)
  return string.rep("│ ", pairs_count) .. "│" .. "  "
end


-- Render a single commit according to the specified mode
local function render_commit(commit, mode_config, window_width)
  -- Default window width if not provided
  window_width = window_width or 80
  local lines = {}
  local is_current = commit:is_current()

  -- Build the main commit line
  local line_parts = {}

  -- Use complete graph structure from new parsing and apply proper colors
  local styled_graph = apply_symbol_colors(commit.complete_graph or "", commit)

  table.insert(line_parts, styled_graph)

  -- Change ID with proper coloring based on shortest unique prefix
  local change_id = commit.short_change_id or commit.change_id:sub(1, 8)
  local shortest_change_id = commit.shortest_change_id or ""
  local change_id_color = is_current and COLORS.change_id_current or COLORS.change_id_regular
  local change_id_dim_color = COLORS.change_id_dim

  -- Color the shortest unique prefix, dim the rest
  local colored_length = #shortest_change_id
  if colored_length > 0 and colored_length < #change_id then
    table.insert(line_parts, change_id_color .. change_id:sub(1, colored_length) .. COLORS.reset)
    table.insert(line_parts, change_id_dim_color .. change_id:sub(colored_length + 1) .. COLORS.reset_fg)
  else
    table.insert(line_parts, change_id_color .. change_id .. COLORS.reset)
  end

  -- Author
  local author = commit:get_author_display()
  if author ~= "" then
    local author_color
    if commit.root then
      author_color = COLORS.author_root
    else
      author_color = is_current and COLORS.author_current or COLORS.author_regular
    end
    table.insert(line_parts, " " .. author_color .. author .. COLORS.reset_fg)
  end

  -- Timestamp
  local timestamp = commit:get_timestamp_display()
  if timestamp ~= "" then
    local timestamp_color = is_current and COLORS.timestamp_current or COLORS.timestamp_regular
    table.insert(line_parts, " " .. timestamp_color .. timestamp .. COLORS.reset_fg)
  end

  -- Bookmarks
  if #commit.bookmarks > 0 then
    local bookmarks_str = commit:get_bookmarks_display()
    if bookmarks_str ~= "" then
      table.insert(line_parts, " " .. COLORS.bookmarks .. bookmarks_str .. COLORS.reset_fg)
    end
  end

  -- Commit ID with proper coloring based on shortest unique prefix
  local commit_id = commit.short_commit_id
  if commit_id ~= "" then
    local shortest_commit_id = commit.shortest_commit_id or ""
    local commit_id_color = is_current and COLORS.commit_id_current or COLORS.commit_id_regular
    local commit_id_dim_color = COLORS.commit_id_dim

    table.insert(line_parts, " ")
    -- Color the shortest unique prefix, dim the rest
    local colored_length = #shortest_commit_id
    if colored_length > 0 and colored_length < #commit_id then
      table.insert(line_parts, commit_id_color .. commit_id:sub(1, colored_length) .. COLORS.reset)
      table.insert(line_parts, commit_id_dim_color .. commit_id:sub(colored_length + 1) .. COLORS.reset_fg)
    else
      table.insert(line_parts, commit_id_color .. commit_id .. COLORS.reset)
    end
  end

  -- Conflict indicator (last item on the line)
  if commit.conflict then
    table.insert(line_parts, " " .. COLORS.conflict_indicator .. "conflict" .. COLORS.reset)
  end

  -- Handle intelligent wrapping of main commit line
  local graph_width = get_display_width(styled_graph)
  local continuation_prefix = get_continuation_graph_from_commit(styled_graph)

  -- Build the line with intelligent wrapping
  local current_line_parts = {}
  local current_width = graph_width
  local wrapped_lines = {}

  for i, part in ipairs(line_parts) do
    local part_width = get_display_width(part)

    -- Check if adding this part would exceed window width
    if current_width + part_width > window_width and #current_line_parts > 0 then
      -- Start a new line with this part, removing any leading space from the part
      table.insert(wrapped_lines, table.concat(current_line_parts))
      local trimmed_part = part:gsub("^%s+", "") -- Remove leading spaces
      current_line_parts = { continuation_prefix .. trimmed_part }
      current_width = get_display_width(continuation_prefix) + get_display_width(trimmed_part)
    else
      -- Add to current line
      table.insert(current_line_parts, part)
      current_width = current_width + part_width
    end
  end

  -- Add the final line
  if #current_line_parts > 0 then
    table.insert(wrapped_lines, table.concat(current_line_parts))
  end

  -- Add all wrapped lines to the commit
  for _, wrapped_line in ipairs(wrapped_lines) do
    table.insert(lines, wrapped_line .. COLORS.reset)
  end

  -- Set the header line for navigation (always the first line)
  commit.header_line = 1

  -- Always add description in comfortable/detailed mode (before connector lines)
  -- Skip description for root commits
  if mode_config.show_description and not mode_config.single_line and not commit.root then
    local description = commit:get_short_description()
    if description and description ~= "" then
      local desc_color
      if commit:has_real_description() then
        -- Real descriptions are white (bold for current commit)
        desc_color = is_current and COLORS.description_real_current or COLORS.description_real_regular
      else
        -- "(no description set)" is yellow
        desc_color = is_current and COLORS.description_current or COLORS.description_regular
      end

      -- Handle "(empty)" coloring separately from description
      local formatted_desc = ""
      if commit.empty and description:find("^%(empty%) ") then
        -- Color "(empty)" in green and rest in description color
        local empty_part = "(empty) "
        local rest_part = description:sub(#empty_part + 1)
        formatted_desc = COLORS.empty_indicator .. empty_part .. COLORS.reset_fg .. desc_color .. rest_part
      else
        -- Normal description coloring
        formatted_desc = desc_color .. description
      end

      -- Use the captured description_graph with proper symbol coloring and wrapping
      local desc_graph = apply_symbol_colors(commit.description_graph or "", commit)
      local desc_content = formatted_desc .. COLORS.reset_fg .. COLORS.reset
      -- Use the description graph structure for continuation
      local continuation_graph = get_continuation_graph_from_commit(commit.description_graph)

      -- Use word-based wrapping for descriptions
      local wrapped_lines = wrap_text_by_words(desc_content, desc_graph, continuation_graph, window_width)

      -- Add each wrapped line
      for _, wrapped_line in ipairs(wrapped_lines) do
        table.insert(lines, wrapped_line)
      end
    end
  end

  -- Add additional lines from parsed graph data (connectors after description)
  if commit.additional_lines and #commit.additional_lines > 0 then
    for _, line_data in ipairs(commit.additional_lines) do
      local full_line = line_data.graph_prefix .. line_data.content
      table.insert(lines, full_line)
    end
  end

  -- Add parent information if configured
  if mode_config.show_parents and #commit.parents > 0 then
    local parents_str = table.concat(commit.parents, ", ")
    local parent_graph = apply_symbol_colors(commit.description_graph or "", commit)
    local parent_content = "parents: " .. parents_str
    local continuation_graph = get_continuation_graph_from_commit(parent_graph)

    -- Use word-based wrapping for parent information
    local wrapped_lines = wrap_text_by_words(parent_content, parent_graph, continuation_graph, window_width)

    -- Add each wrapped line
    for _, wrapped_line in ipairs(wrapped_lines) do
      table.insert(lines, wrapped_line)
    end
  end

  -- Store the rendered lines in the commit object
  commit.lines = lines

  return lines
end


-- Render elided section
local function render_elided_section(elided_entry)
  local lines = {}
  for _, line in ipairs(elided_entry.lines) do
    table.insert(lines, line)
  end
  return lines
end

-- Render a list of mixed entries (commits and elided sections) with line number tracking
M.render_commits = function(mixed_entries, mode, window_width)
  mode = mode or config.get('log.format') or 'comfortable'
  local mode_config = RENDER_MODES[mode] or RENDER_MODES.comfortable

  -- Get window width from config if not provided
  if not window_width then
    window_width = config.get('window.width') or 80
  end

  local all_lines = {}
  local line_number = 1

  -- Defensive check to ensure mixed_entries is a table
  if not mixed_entries or type(mixed_entries) ~= 'table' then
    mixed_entries = {}
  end

  for _, entry in ipairs(mixed_entries) do
    if entry.type == "elided" then
      -- Handle elided section
      entry.line_start = line_number

      local elided_lines = render_elided_section(entry)

      -- Add lines to the overall display
      for _, line in ipairs(elided_lines) do
        table.insert(all_lines, line)
        line_number = line_number + 1
      end

      entry.line_end = line_number - 1
    elseif entry.type == "connector" then
      -- Handle standalone connector section
      entry.line_start = line_number

      -- Add connector lines directly to display
      for _, line in ipairs(entry.lines) do
        table.insert(all_lines, line)
        line_number = line_number + 1
      end

      entry.line_end = line_number - 1
    else
      -- Handle commit (entry is a commit object)
      local commit = entry

      -- Set the starting line for this commit
      commit.line_start = line_number

      -- Render the commit with window width for wrapping
      local commit_lines = render_commit(commit, mode_config, window_width)

      -- Add lines to the overall display
      for _, line in ipairs(commit_lines) do
        table.insert(all_lines, line)
        line_number = line_number + 1
      end

      -- Set the ending line for this commit
      commit.line_end = line_number - 1

      -- Adjust header_line to be absolute (not relative to commit)
      if commit.header_line then
        commit.header_line = commit.line_start + commit.header_line - 1
      end
    end
  end

  return all_lines
end

-- Parse the rendered lines with ANSI codes for highlighting
M.render_with_highlights = function(commits, mode, window_width)
  local display_lines = M.render_commits(commits, mode, window_width)
  local highlighted_lines = {}

  for i, line in ipairs(display_lines) do
    -- Parse ANSI codes and create highlight segments
    local segments = ansi.parse_ansi_line(line)
    highlighted_lines[i] = {
      text = ansi.strip_ansi(line), -- Plain text for buffer
      segments = segments           -- Highlight information
    }
  end

  return highlighted_lines, display_lines
end

-- Get available rendering modes
M.get_available_modes = function()
  local modes = {}
  for mode, _ in pairs(RENDER_MODES) do
    table.insert(modes, mode)
  end
  return modes
end

-- Get the commit that contains a specific line number
M.get_commit_at_line = function(mixed_entries, line_number)
  for _, entry in ipairs(mixed_entries) do
    if entry.line_start and entry.line_end then
      if line_number >= entry.line_start and line_number <= entry.line_end then
        -- Only return commit entries, not elided sections
        if entry.type == "elided" then
          return nil   -- Elided sections are not navigable
        else
          return entry -- This is a commit
        end
      end
    end
  end
  return nil
end

-- Get the header line number for a commit (for navigation)
M.get_commit_header_line = function(commit)
  return commit.header_line or commit.line_start or 1
end

-- Get all commit header lines (for navigation targets)
M.get_all_header_lines = function(mixed_entries)
  local header_lines = {}
  for _, entry in ipairs(mixed_entries) do
    -- Only include commits, not elided sections
    if entry.type ~= "elided" then
      local commit = entry
      local header_line = M.get_commit_header_line(commit)
      table.insert(header_lines, header_line)
    end
  end
  return header_lines
end

return M
