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

-- Color codes that match jj's actual output for consistency
local COLORS = {
  current_symbol = '\27[1m\27[38;5;2m', -- @ symbol (bold green)
  regular_symbol = '', -- ○ symbol (no color)
  root_symbol = '\27[1m\27[38;5;14m', -- ◆ symbol (bold bright cyan)
  conflict_symbol = '\27[1m\27[38;5;1m', -- × symbol (bold red)
  change_id_current = '\27[1m\27[38;5;13m', -- Current commit change ID (bold bright magenta)
  change_id_regular = '\27[1m\27[38;5;13m', -- Regular commit change ID (bold bright magenta) - matches actual jj
  change_id_dim = '\27[38;5;8m', -- Dim part of change ID
  author_current = '\27[1m\27[38;5;3m', -- Current commit author (bold yellow)
  author_regular = '\27[38;5;3m', -- Regular commit author (yellow)
  author_root = '\27[38;5;2m', -- Root commit author (dark green)
  timestamp_current = '\27[38;5;14m', -- Current commit timestamp (bright cyan) - matches actual jj
  timestamp_regular = '\27[38;5;14m', -- Regular commit timestamp (bright cyan) - matches actual jj
  commit_id_current = '\27[38;5;12m', -- Current commit ID (bright blue) - matches actual jj
  commit_id_regular = '\27[38;5;12m', -- Regular commit ID (bright blue) - matches actual jj
  commit_id_dim = '\27[38;5;8m', -- Dim part of commit ID
  description_current = '\27[1m\27[38;5;3m', -- Current commit "(no description set)" (bold yellow)
  description_regular = '\27[38;5;3m', -- Regular commit "(no description set)" (yellow)
  description_real_current = '\27[1m', -- Current commit real description (bold white)
  description_real_regular = '', -- Regular commit real description (white)
  empty_indicator = '\27[38;5;2m', -- "(empty)" indicator (green)
  bookmarks = '\27[1m\27[38;5;5m', -- Bookmarks (bold purple)
  conflict_indicator = '\27[38;5;1m', -- "conflict" indicator (red)
  elided_revisions = '\27[38;5;8m', -- "~" and "(elided revisions)" text (dim gray)
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
  
  -- Color all diamond symbols regardless of commit type
  result = result:gsub("◆", COLORS.root_symbol .. "◆" .. COLORS.reset_fg)

  return result
end

-- Helper function to generate continuation graph from commit graph structure
local function get_continuation_graph_from_commit(source_line)
  if not source_line or source_line == "" then
    return ""
  end

  -- Strip ANSI codes to get clean structure for analysis
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
  
  -- Build continuation graph preserving original spacing structure
  local result = ""
  local char_count = vim.fn.strchars(graph_content)
  
  -- Process each character in the graph content
  for i = 0, char_count - 1 do
    local char = vim.fn.strcharpart(graph_content, i, 1)
    
    if char == " " then
      -- Preserve spaces exactly as they are
      result = result .. " "
    elseif char == "│" then
      -- Keep vertical bars as they are
      result = result .. "│"
    elseif char == "@" or char == "○" or char == "◆" or char == "×" then
      -- Replace commit symbols with vertical bars to maintain flow
      result = result .. "│"
    elseif char == "─" then
      -- Horizontal lines become spaces in continuation area
      result = result .. " "
    elseif char:match("[├┤╭╰╮╯]") then
      -- Complex connectors become vertical bars to maintain column flow
      result = result .. "│"
    else
      -- Any other symbol becomes vertical bar
      result = result .. "│"
    end
  end
  
  -- Ensure we have proper spacing after the graph for text indentation
  if not result:match("%s%s$") then
    result = result .. "  "
  end
  
  return result
end


-- Render a single commit according to the specified mode
local function render_commit(commit, mode_config, window_width)
  -- Default window width if not provided
  window_width = window_width or 80
  local lines = {}
  local is_current = commit:is_current()

  -- Build the main commit line using structured parts
  local main_parts = commit:get_main_line_parts()
  local line_parts = {}
  
  for _, part in ipairs(main_parts) do
    if part:has_content() then
      table.insert(line_parts, part:get_styled_text())
    end
  end

  -- Handle intelligent wrapping of main commit line
  -- Get the graph part for width calculation and continuation
  local graph_part = main_parts[1]  -- Graph is always first
  local styled_graph = graph_part:get_styled_text()
  local graph_width = graph_part:get_width()
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
    -- Get description(s) based on expansion state (without empty prefix)
    local descriptions = {}
    if commit.expanded then
      descriptions = commit:get_description_lines_only()
    else
      local desc_text = commit:get_description_text_only()
      if desc_text and desc_text ~= "" then
        descriptions = {desc_text}
      end
    end
    
    if #descriptions > 0 then
      local desc_color
      if commit:has_real_description() then
        -- Real descriptions are white (bold for current commit)
        desc_color = is_current and COLORS.description_real_current or COLORS.description_real_regular
      else
        -- "(no description set)" is yellow
        desc_color = is_current and COLORS.description_current or COLORS.description_regular
      end

      -- Use the captured description_graph with proper symbol coloring and wrapping
      local desc_graph = apply_symbol_colors(commit.description_graph or "", commit)
      -- Use the description graph structure for continuation
      local continuation_graph = get_continuation_graph_from_commit(commit.description_graph)

      -- Process each description line
      for i, description in ipairs(descriptions) do
        -- Apply description color without empty prefix
        local formatted_desc = desc_color .. description

        -- Add expansion indicator for expandable descriptions (only on first line when not expanded)
        if i == 1 and not commit.expanded and commit:has_expandable_description() then
          formatted_desc = formatted_desc .. COLORS.reset_fg .. COLORS.change_id_dim .. " ▶" .. COLORS.reset_fg
        elseif i == 1 and commit.expanded and commit:has_expandable_description() then
          formatted_desc = formatted_desc .. COLORS.reset_fg .. COLORS.change_id_dim .. " ▼" .. COLORS.reset_fg
        end

        local desc_content = formatted_desc .. COLORS.reset_fg .. COLORS.reset

        -- For expanded descriptions, first line uses desc_graph, subsequent lines use spaces
        local line_graph = desc_graph
        if commit.expanded and i > 1 then
          -- Create a space-filled graph for continuation lines
          local graph_length = vim.fn.strdisplaywidth(ansi.strip_ansi(desc_graph))
          line_graph = string.rep(" ", graph_length)
        end

        -- For expanded descriptions, use space-filled continuation instead of graph continuation
        local wrap_continuation = continuation_graph
        if commit.expanded then
          -- Use spaces for wrapped lines within expanded descriptions
          local graph_length = vim.fn.strdisplaywidth(ansi.strip_ansi(line_graph))
          wrap_continuation = string.rep(" ", graph_length)
        end

        -- Calculate effective window width for description wrapping
        local effective_window_width = window_width
        
        -- For first description line, account for prefix parts that will be inserted
        if i == 1 then
          local desc_prefix_parts = commit:get_description_prefix_parts()
          local total_prefix_width = 0
          
          for _, prefix_part in ipairs(desc_prefix_parts) do
            if prefix_part:has_content() then
              total_prefix_width = total_prefix_width + prefix_part:get_width()
            end
          end
          
          if total_prefix_width > 0 then
            effective_window_width = window_width - total_prefix_width
          end
        end

        -- Use word-based wrapping for descriptions (only the actual description text)
        local wrapped_lines = wrap_text_by_words(desc_content, line_graph, wrap_continuation, effective_window_width)

        -- Add each wrapped line, but add prefix parts to first line if needed
        for j, wrapped_line in ipairs(wrapped_lines) do
          if i == 1 and j == 1 then
            -- Insert any prefix parts (like empty indicator) for first description line
            local desc_prefix_parts = commit:get_description_prefix_parts()
            
            for _, prefix_part in ipairs(desc_prefix_parts) do
              if prefix_part:has_content() then
                -- Insert prefix part after the graph prefix but before the description text
                local prefix_styled = prefix_part:get_styled_text()
                
                -- Strip ANSI codes to find the graph structure more reliably
                local clean_line = ansi.strip_ansi(wrapped_line)
                
                -- Find where graph ends by looking for the pattern: graph symbols followed by 2+ spaces
                local graph_end_match = clean_line:match("^(.*[│├─┤╭╰╮╯]  )")
                
                if graph_end_match then
                  -- We found the graph structure, insert prefix part after it
                  local graph_prefix_len = #graph_end_match
                  
                  -- Find the equivalent position in the original line with ANSI codes
                  local original_pos = 1
                  local clean_pos = 1
                  local target_pos = nil
                  
                  -- Scan through the original line, tracking clean position
                  while original_pos <= #wrapped_line and clean_pos <= graph_prefix_len do
                    -- Check if we're at an ANSI sequence
                    local esc_start, esc_end = wrapped_line:find('\27%[[%d;]*m', original_pos)
                    
                    if esc_start and esc_start == original_pos then
                      -- Skip ANSI sequence in original, don't advance clean position
                      original_pos = esc_end + 1
                    else
                      -- Regular character
                      clean_pos = clean_pos + 1
                      original_pos = original_pos + 1
                      if clean_pos > graph_prefix_len then
                        target_pos = original_pos
                        break
                      end
                    end
                  end
                  
                  if target_pos then
                    -- Insert prefix part at the correct position
                    wrapped_line = wrapped_line:sub(1, target_pos - 1) .. prefix_styled .. wrapped_line:sub(target_pos)
                  else
                    -- Fallback: append to end
                    wrapped_line = wrapped_line .. " " .. prefix_styled
                  end
                else
                  -- No clear graph pattern found, just prepend
                  wrapped_line = prefix_styled .. wrapped_line
                end
              end
            end
          end
          table.insert(lines, wrapped_line)
        end
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


-- Render elided section using structured parts
local function render_elided_section(elided_entry)
  local lines = {}
  
  -- Get all line parts for this elided section
  local all_line_parts = elided_entry:get_all_line_parts()
  
  for line_index, line_parts in ipairs(all_line_parts) do
    local rendered_parts = {}
    
    for _, part in ipairs(line_parts) do
      if part:has_content() then
        table.insert(rendered_parts, part:get_styled_text())
      end
    end
    
    -- Combine all parts for this line
    local rendered_line = table.concat(rendered_parts) .. COLORS.reset
    table.insert(lines, rendered_line)
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
  
  -- Note: window_width here should already be the effective width passed from the caller

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

      -- Mark as commit type for interface compatibility
      commit.content_type = "commit"

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
    local clean_text = ansi.strip_ansi(line)
    
    -- Add right padding space for visual balance
    clean_text = clean_text .. " "
    
    highlighted_lines[i] = {
      text = clean_text,  -- Plain text for buffer with right padding
      segments = segments -- Highlight information
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

-- Expose color definitions for use by other modules
M.get_colors = function()
  return COLORS
end

-- Expose helper functions for use by other modules
M.get_display_width = get_display_width
M.apply_symbol_colors = apply_symbol_colors

return M
