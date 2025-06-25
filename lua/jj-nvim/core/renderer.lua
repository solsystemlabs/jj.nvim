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

-- Helper function to inject graph characters at wrap points
local function inject_graph_chars_for_wrapping(text, graph_prefix, window_width)
  if not text or text == "" or not window_width then
    return {text}
  end
  
  local text_width = get_display_width(text)
  local graph_width = get_display_width(graph_prefix or "")
  
  -- If the line doesn't exceed window width, no injection needed
  if text_width <= window_width then
    return {text}
  end
  
  -- Calculate where wraps will occur and split the text
  local lines = {}
  local remaining_text = text
  local available_width = window_width - graph_width
  
  while get_display_width(remaining_text) > available_width do
    -- Find a good break point
    local break_point = available_width
    
    -- Try to break at word boundary (find last space within available width)
    local clean_text = ansi.strip_ansi(remaining_text)
    local last_space = clean_text:sub(1, available_width):find(" [^ ]*$")
    if last_space and last_space > available_width * 0.7 then
      break_point = last_space - 1
    end
    
    -- Extract the portion that fits
    local line_portion = remaining_text:sub(1, break_point)
    table.insert(lines, line_portion)
    
    -- Remove the extracted portion and trim leading spaces
    remaining_text = remaining_text:sub(break_point + 1):gsub("^%s+", "")
  end
  
  -- Add the remaining text
  if remaining_text ~= "" then
    table.insert(lines, remaining_text)
  end
  
  return lines
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
  result = result:gsub("×", "\27[31m×\27[0m")
  
  -- Then apply commit-specific symbol coloring
  if is_current then
    result = result:gsub("@", COLORS.current_symbol .. "@" .. COLORS.reset_fg)
  end
  if commit.root then
    result = result:gsub("◆", COLORS.root_symbol .. "◆" .. COLORS.reset_fg)
  end
  
  return result
end

-- Helper function to generate continuation graph for wrapped lines
local function get_continuation_graph(graph_prefix)
  if not graph_prefix or graph_prefix == "" then
    return ""
  end
  
  -- Strip ANSI codes for analysis
  local clean_graph = ansi.strip_ansi(graph_prefix)
  local result = ""
  
  -- Replace graph symbols, keeping the column structure
  for i = 1, vim.fn.strchars(clean_graph) do
    local char = vim.fn.strcharpart(clean_graph, i - 1, 1)
    if char == " " then
      result = result .. " "
    elseif char == "│" then
      result = result .. "│"
    elseif char == "─" then
      result = result .. " "  -- horizontal lines become spaces
    else
      -- Other graph characters (├, ╮, ╯, ╭, ┤, ×, ○, @, ◆) become │
      result = result .. "│"
    end
  end
  
  return result
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
  local graph = apply_symbol_colors(commit.complete_graph or "", commit)

  table.insert(line_parts, graph)

  -- table.insert(line_parts, "  ") -- Spacing after graph

  -- Change ID with proper coloring
  local change_id = commit.short_change_id or commit.change_id:sub(1, 8)
  local change_id_color = is_current and COLORS.change_id_current or COLORS.change_id_regular
  local change_id_dim_color = COLORS.change_id_dim

  if #change_id > 1 then
    table.insert(line_parts, change_id_color .. change_id:sub(1, 1) .. COLORS.reset)
    table.insert(line_parts, change_id_dim_color .. change_id:sub(2) .. COLORS.reset_fg)
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

  -- Commit ID
  local commit_id = commit.short_commit_id
  if commit_id ~= "" then
    local commit_id_color = is_current and COLORS.commit_id_current or COLORS.commit_id_regular
    local commit_id_dim_color = COLORS.commit_id_dim

    table.insert(line_parts, " ")
    if #commit_id > 1 then
      table.insert(line_parts, commit_id_color .. commit_id:sub(1, 1) .. COLORS.reset)
      table.insert(line_parts, commit_id_dim_color .. commit_id:sub(2) .. COLORS.reset_fg)
    else
      table.insert(line_parts, commit_id_color .. commit_id .. COLORS.reset)
    end
  end

  -- Complete the main line
  local main_line = table.concat(line_parts) .. COLORS.reset
  table.insert(lines, main_line)

  -- Set the header line for navigation (always the first line)
  commit.header_line = 1

  -- Add additional lines from parsed graph data (descriptions, connectors, bookmarks)
  if commit.additional_lines and #commit.additional_lines > 0 then
    for _, line_data in ipairs(commit.additional_lines) do
      local full_line = line_data.graph_prefix .. line_data.content
      table.insert(lines, full_line)
    end
  end
  
  -- Always add description for non-root commits in comfortable/detailed mode
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
      
      -- Inject graph characters for proper wrapping
      local wrapped_lines = inject_graph_chars_for_wrapping(desc_content, desc_graph, window_width)
      
      -- Add each wrapped line with appropriate graph prefix
      for i, wrapped_text in ipairs(wrapped_lines) do
        local line_graph
        if i == 1 then
          -- First line: use original graph structure
          line_graph = desc_graph
        else
          -- Continuation lines: use simple │ continuation
          line_graph = get_continuation_graph(desc_graph)
        end
        local desc_line = line_graph .. wrapped_text
        table.insert(lines, desc_line)
      end
    end
  end

  -- Add bookmarks if configured
  if mode_config.show_bookmarks and #commit.bookmarks > 0 then
    local bookmarks_str = commit:get_bookmarks_display()
    if bookmarks_str ~= "" then
      local bookmark_graph = apply_symbol_colors(commit.description_graph or "", commit)
      local bookmark_content = "bookmarks: " .. bookmarks_str
      
      -- Inject graph characters for proper wrapping
      local wrapped_lines = inject_graph_chars_for_wrapping(bookmark_content, bookmark_graph, window_width)
      
      -- Add each wrapped line with appropriate graph prefix
      for i, wrapped_text in ipairs(wrapped_lines) do
        local line_graph
        if i == 1 then
          -- First line: use original graph structure
          line_graph = bookmark_graph
        else
          -- Continuation lines: use simple │ continuation
          line_graph = get_continuation_graph(bookmark_graph)
        end
        local bookmark_line = line_graph .. wrapped_text
        table.insert(lines, bookmark_line)
      end
    end
  end

  -- Add parent information if configured
  if mode_config.show_parents and #commit.parents > 0 then
    local parents_str = table.concat(commit.parents, ", ")
    local parent_graph = apply_symbol_colors(commit.description_graph or "", commit)
    local parent_content = "parents: " .. parents_str
    
    -- Inject graph characters for proper wrapping
    local wrapped_lines = inject_graph_chars_for_wrapping(parent_content, parent_graph, window_width)
    
    -- Add each wrapped line with appropriate graph prefix
    for i, wrapped_text in ipairs(wrapped_lines) do
      local line_graph
      if i == 1 then
        -- First line: use original graph structure
        line_graph = parent_graph
      else
        -- Continuation lines: use simple │ continuation
        line_graph = get_continuation_graph(parent_graph)
      end
      local parent_line = line_graph .. wrapped_text
      table.insert(lines, parent_line)
    end
  end

  -- Store the rendered lines in the commit object
  commit.lines = lines

  return lines
end


-- Render a list of commits with line number tracking
M.render_commits = function(commits, mode, window_width)
  mode = mode or config.get('log.format') or 'comfortable'
  local mode_config = RENDER_MODES[mode] or RENDER_MODES.comfortable

  -- Get window width from config if not provided
  if not window_width then
    window_width = config.get('window.width') or 80
  end

  local all_lines = {}
  local line_number = 1

  -- Defensive check to ensure commits is a table
  if not commits or type(commits) ~= 'table' then
    commits = {}
  end

  for _, commit in ipairs(commits) do
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
M.get_commit_at_line = function(commits, line_number)
  for _, commit in ipairs(commits) do
    if commit.line_start and commit.line_end then
      if line_number >= commit.line_start and line_number <= commit.line_end then
        return commit
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
M.get_all_header_lines = function(commits)
  local header_lines = {}
  for _, commit in ipairs(commits) do
    local header_line = M.get_commit_header_line(commit)
    table.insert(header_lines, header_line)
  end
  return header_lines
end

return M

