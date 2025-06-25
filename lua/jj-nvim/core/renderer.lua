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
  current_symbol = '\27[1m\27[38;5;2m',      -- @ symbol (bold green)
  regular_symbol = '',                        -- ○ symbol (no color)
  change_id_current = '\27[1m\27[38;5;13m',  -- Current commit change ID (bold magenta)
  change_id_regular = '\27[1m\27[38;5;5m',   -- Regular commit change ID (bold purple)
  change_id_dim = '\27[38;5;8m',             -- Dim part of change ID
  author_current = '\27[1m\27[38;5;3m',      -- Current commit author (bold yellow)
  author_regular = '\27[38;5;3m',            -- Regular commit author (yellow)
  author_root = '\27[38;5;2m',               -- Root commit author (dark green)
  timestamp_current = '\27[38;5;14m',        -- Current commit timestamp (bright cyan)
  timestamp_regular = '\27[38;5;6m',         -- Regular commit timestamp (cyan)
  commit_id_current = '\27[38;5;12m',        -- Current commit ID (bright blue)
  commit_id_regular = '\27[1m\27[38;5;4m',   -- Regular commit ID (bold blue)
  commit_id_dim = '\27[38;5;8m',             -- Dim part of commit ID
  description_current = '\27[1m\27[38;5;3m', -- Current commit "(no description set)" (bold yellow)
  description_regular = '\27[38;5;3m',       -- Regular commit "(no description set)" (yellow)
  description_real_current = '\27[1m',       -- Current commit real description (bold white)
  description_real_regular = '',             -- Regular commit real description (white)
  branch_symbol = '│',                       -- Branch continuation symbol
  reset = '\27[0m',                          -- Reset all formatting
  reset_fg = '\27[39m',                      -- Reset foreground only
}

-- Render a single commit according to the specified mode
local function render_commit(commit, mode_config)
  local lines = {}
  local is_current = commit:is_current()
  
  -- Build the main commit line
  local line_parts = {}
  
  -- Symbol (@ or ○ or ◆)
  local symbol = commit:get_symbol()
  if is_current then
    table.insert(line_parts, COLORS.current_symbol .. symbol .. COLORS.reset)
  else
    table.insert(line_parts, symbol)
  end
  
  table.insert(line_parts, "  ") -- Spacing after symbol
  
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
  
  -- Add description if configured (but not for root commits)
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
      local desc_line = COLORS.branch_symbol .. "  " .. desc_color .. description .. COLORS.reset_fg .. COLORS.reset
      table.insert(lines, desc_line)
    end
  end
  
  -- Add bookmarks if configured
  if mode_config.show_bookmarks and #commit.bookmarks > 0 then
    local bookmarks_str = commit:get_bookmarks_display()
    if bookmarks_str ~= "" then
      local bookmark_line = COLORS.branch_symbol .. "  bookmarks: " .. bookmarks_str
      table.insert(lines, bookmark_line)
    end
  end
  
  -- Add parent information if configured
  if mode_config.show_parents and #commit.parents > 0 then
    local parents_str = table.concat(commit.parents, ", ")
    local parent_line = COLORS.branch_symbol .. "  parents: " .. parents_str
    table.insert(lines, parent_line)
  end
  
  -- Store the rendered lines in the commit object
  commit.lines = lines
  
  return lines
end

-- Wrap clean text (no ANSI codes) into multiple lines
local function wrap_clean_text(text, window_width)
  if #text <= window_width then
    return {text}
  end
  
  local wrapped_lines = {}
  local remaining = text
  
  while #remaining > 0 do
    local wrap_point = math.min(window_width, #remaining)
    
    -- If this isn't the last piece, try to break at word boundary
    if wrap_point < #remaining then
      local space_pos = remaining:sub(1, wrap_point):match("^.*() ")
      if space_pos and space_pos > wrap_point * 0.7 then -- Only break at space if it's reasonably far
        wrap_point = space_pos - 1
      end
    end
    
    -- Extract the portion that fits
    local line_text = remaining:sub(1, wrap_point)
    table.insert(wrapped_lines, line_text)
    
    -- Move to next portion, trimming leading whitespace
    remaining = remaining:sub(wrap_point + 1)
    remaining = remaining:match("^%s*(.*)") or ""
  end
  
  return wrapped_lines
end

-- Reconstruct text with colors from original segments
local function reconstruct_with_colors(target_text, segments, text_offset)
  if not target_text or target_text == "" then
    return ""
  end
  
  -- Build a mapping of character positions to highlights in the original text
  local char_highlights = {}
  local original_pos = 1
  
  for _, segment in ipairs(segments) do
    local segment_text = segment.text
    for i = 1, #segment_text do
      char_highlights[original_pos + i - 1] = segment.highlight
    end
    original_pos = original_pos + #segment_text
  end
  
  -- Now reconstruct the target text with highlights
  local result_segments = {}
  local current_highlight = nil
  local current_text = ""
  
  for i = 1, #target_text do
    local char = target_text:sub(i, i)
    local highlight = char_highlights[text_offset + i] -- Map to original position
    
    if highlight == current_highlight then
      -- Same highlight, accumulate text
      current_text = current_text .. char
    else
      -- Highlight changed, flush current segment
      if current_text ~= "" then
        table.insert(result_segments, {
          text = current_text,
          highlight = current_highlight
        })
      end
      
      -- Start new segment
      current_highlight = highlight
      current_text = char
    end
  end
  
  -- Flush final segment
  if current_text ~= "" then
    table.insert(result_segments, {
      text = current_text,
      highlight = current_highlight
    })
  end
  
  -- Convert segments back to ANSI-colored text
  local result = ""
  for _, segment in ipairs(result_segments) do
    result = result .. segment.text
  end
  
  return result
end

-- Smart wrapping that preserves colors by keeping original line structure
local function wrap_line_with_graph(line, window_width, is_header_line)
  local clean_text = ansi.strip_ansi(line)
  
  -- If line fits, no wrapping needed
  if #clean_text <= window_width then
    return line
  end
  
  -- Wrap the clean text to get break points
  local wrapped_clean = wrap_clean_text(clean_text, window_width)
  
  -- For the first line, truncate the original line at the clean text break point
  -- For continuation lines, use plain text (simpler and more reliable)
  local result_lines = {}
  local clean_chars_processed = 0
  
  for i, clean_portion in ipairs(wrapped_clean) do
    if i == 1 then
      -- First line: truncate original line to match the clean portion length
      local target_clean_chars = #clean_portion
      local original_pos = 1
      local clean_chars_seen = 0
      
      -- Walk through original line, counting clean characters
      while original_pos <= #line and clean_chars_seen < target_clean_chars do
        local char = line:sub(original_pos, original_pos)
        if char == string.char(27) then -- ESC character
          -- Skip ANSI escape sequence
          local esc_end = line:find("m", original_pos)
          if esc_end then
            original_pos = esc_end + 1
          else
            original_pos = original_pos + 1
          end
        else
          clean_chars_seen = clean_chars_seen + 1
          original_pos = original_pos + 1
        end
      end
      
      -- Include any trailing ANSI reset codes
      local first_line = line:sub(1, original_pos - 1)
      -- Ensure we end with a reset if we're in the middle of formatting
      if not first_line:match("\27%[0m$") and first_line:match("\27%[") then
        first_line = first_line .. COLORS.reset
      end
      
      table.insert(result_lines, first_line)
    else
      -- Continuation lines: use plain text with graph prefix
      table.insert(result_lines, COLORS.branch_symbol .. "  " .. clean_portion)
    end
  end
  
  return table.concat(result_lines, "\n")
end

-- Render a list of commits with line number tracking and smart wrapping
M.render_commits = function(commits, mode)
  mode = mode or config.get('log.format') or 'comfortable'
  local mode_config = RENDER_MODES[mode] or RENDER_MODES.comfortable
  
  -- Get current window width for wrapping calculations
  local window_width = config.get('window.width') or 70
  
  local all_lines = {}
  local line_number = 1
  
  for _, commit in ipairs(commits) do
    -- Set the starting line for this commit
    commit.line_start = line_number
    
    -- Render the commit
    local commit_lines = render_commit(commit, mode_config)
    
    -- Add lines to the overall display with smart wrapping
    for line_index, line in ipairs(commit_lines) do
      local is_header_line = line_index == 1
      local wrapped_result = wrap_line_with_graph(line, window_width, is_header_line)
      
      -- Handle multiple lines from wrapping
      if wrapped_result:find('\n') then
        local wrapped_lines = vim.split(wrapped_result, '\n', { plain = true })
        for _, wrapped_line in ipairs(wrapped_lines) do
          table.insert(all_lines, wrapped_line)
          line_number = line_number + 1
        end
      else
        table.insert(all_lines, wrapped_result)
        line_number = line_number + 1
      end
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
M.render_with_highlights = function(commits, mode)
  local display_lines = M.render_commits(commits, mode)
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