local M = {}

local jj_colors = require('jj-nvim.utils.jj_colors')

-- Basic ANSI color codes for fallback
local basic_ansi_colors = {
  ['30'] = 'black',
  ['31'] = 'red',
  ['32'] = 'green',
  ['33'] = 'yellow',
  ['34'] = 'blue',
  ['35'] = 'magenta',
  ['36'] = 'cyan',
  ['37'] = 'white',
  ['90'] = 'bright_black',
  ['91'] = 'bright_red',
  ['92'] = 'bright_green',
  ['93'] = 'bright_yellow',
  ['94'] = 'bright_blue',
  ['95'] = 'bright_magenta',
  ['96'] = 'bright_cyan',
  ['97'] = 'bright_white',
}

local basic_ansi_bg_colors = {
  ['40'] = 'black',
  ['41'] = 'red',
  ['42'] = 'green',
  ['43'] = 'yellow',
  ['44'] = 'blue',
  ['45'] = 'magenta',
  ['46'] = 'cyan',
  ['47'] = 'white',
  ['100'] = 'bright_black',
  ['101'] = 'bright_red',
  ['102'] = 'bright_green',
  ['103'] = 'bright_yellow',
  ['104'] = 'bright_blue',
  ['105'] = 'bright_magenta',
  ['106'] = 'bright_cyan',
  ['107'] = 'bright_white',
}

M.setup_highlights = function()
  -- Basic highlights for text styling
  vim.api.nvim_set_hl(0, 'JJAnsiBold', { bold = true })
  vim.api.nvim_set_hl(0, 'JJAnsiDim', { fg = 'Gray' })
  vim.api.nvim_set_hl(0, 'JJAnsiItalic', { italic = true })
  vim.api.nvim_set_hl(0, 'JJAnsiUnderline', { underline = true })
end

M.parse_ansi_line = function(line)
  local segments = {}
  local pos = 1
  local current_attrs = {}

  -- Check if this line is part of the current commit (working copy)
  local stripped_line = line:gsub('\27%[[%d;]*m', '') -- Remove ANSI codes
  local is_current_commit = false

  if stripped_line:match('^@') then
    -- Line starts with @ symbol - definitely current commit
    is_current_commit = true
  elseif stripped_line:match('^│.*%(no description set%)') then
    -- Description line for current commit
    is_current_commit = line:find('\27%[1m\27%[38;5;3m') ~= nil -- Bold yellow for current commit description
  end

  -- Debug: show current commit detection
  -- if is_current_commit then
  --   vim.notify("CURRENT COMMIT DETECTED: " .. stripped_line:sub(1, 40), vim.log.levels.INFO)
  -- end

  while pos <= #line do
    local esc_start, esc_end = line:find('\27%[[%d;]*m', pos)

    if not esc_start then
      if pos <= #line then
        table.insert(segments, {
          text = line:sub(pos),
          highlight = M.get_highlight_name(current_attrs, is_current_commit)
        })
      end
      break
    end

    if esc_start > pos then
      table.insert(segments, {
        text = line:sub(pos, esc_start - 1),
        highlight = M.get_highlight_name(current_attrs, is_current_commit)
      })
    end

    local codes = line:sub(esc_start + 2, esc_end - 1):match('([%d;]*)')
    M.update_attributes(current_attrs, codes)

    pos = esc_end + 1
  end

  return segments
end

M.update_attributes = function(attrs, codes)
  if codes == '' or codes == '0' then
    for k in pairs(attrs) do
      attrs[k] = nil
    end
    return
  end

  local parts = vim.split(codes, ';', { plain = true })
  local i = 1

  while i <= #parts do
    local code = parts[i]

    if code == '1' then
      attrs.bold = true
    elseif code == '2' then
      attrs.dim = true
    elseif code == '3' then
      attrs.italic = true
    elseif code == '4' then
      attrs.underline = true
    elseif code == '38' and parts[i + 1] == '5' and parts[i + 2] then
      -- 256-color foreground: 38;5;n
      local color_num = tonumber(parts[i + 2])
      if color_num then
        attrs.fg = color_num
      end
      i = i + 2
    elseif code == '48' and parts[i + 1] == '5' and parts[i + 2] then
      -- 256-color background: 48;5;n
      local color_num = tonumber(parts[i + 2])
      if color_num then
        attrs.bg = color_num
      end
      i = i + 2
    elseif code == '39' then
      -- Reset foreground
      attrs.fg = nil
    elseif code == '49' then
      -- Reset background
      attrs.bg = nil
    elseif basic_ansi_colors[code] then
      attrs.fg = basic_ansi_colors[code]
    elseif basic_ansi_bg_colors[code] then
      attrs.bg = basic_ansi_bg_colors[code]
    end

    i = i + 1
  end
end

M.get_highlight_name = function(attrs, is_current_commit)
  if not next(attrs) then
    return nil
  end

  local parts = {}
  if attrs.fg then
    if type(attrs.fg) == 'number' then
      -- Create different highlight names for current commit to avoid caching conflicts
      local suffix = (is_current_commit and attrs.fg == 3) and '_current' or ''
      table.insert(parts, 'JJAnsi256_' .. attrs.fg .. suffix)
    else
      table.insert(parts, 'JJAnsi' .. attrs.fg)
    end
  end
  if attrs.bg then
    if type(attrs.bg) == 'number' then
      table.insert(parts, 'JJAnsiBg256_' .. attrs.bg)
    else
      table.insert(parts, 'JJAnsiBg' .. attrs.bg)
    end
  end
  if attrs.bold then
    table.insert(parts, 'JJAnsiBold')
  end
  if attrs.dim then
    table.insert(parts, 'JJAnsiDim')
  end
  if attrs.italic then
    table.insert(parts, 'JJAnsiItalic')
  end
  if attrs.underline then
    table.insert(parts, 'JJAnsiUnderline')
  end

  if #parts == 0 then
    return nil
  end

  local hl_name = table.concat(parts, '_')

  local hl_attrs = {}
  if attrs.fg then
    if type(attrs.fg) == 'number' then
      -- Convert 256-color number to hex color, considering bold for brighter colors
      local hex_color = M.color_256_to_hex(attrs.fg, is_current_commit, attrs.bold)
      hl_attrs.fg = hex_color
      -- Debug: uncomment to see color mappings
      -- print("Color " .. attrs.fg .. " -> " .. hex_color .. (is_current_commit and " (current)" or "") .. (attrs.bold and " (bold)" or ""))
    else
      hl_attrs.fg = attrs.fg -- Use the color name
    end
  end
  if attrs.bg then
    if type(attrs.bg) == 'number' then
      -- Convert 256-color number to hex color
      hl_attrs.bg = M.color_256_to_hex(attrs.bg)
    else
      hl_attrs.bg = attrs.bg -- Use the color name
    end
  end
  if attrs.bold then hl_attrs.bold = true end
  if attrs.dim then hl_attrs.fg = 'Gray' end
  if attrs.italic then hl_attrs.italic = true end
  if attrs.underline then hl_attrs.underline = true end

  vim.api.nvim_set_hl(0, hl_name, hl_attrs)

  return hl_name
end

M.color_256_to_hex = function(color_num, is_current_commit, is_bold)
  -- Debug: show what colors we're processing
  -- vim.notify("Processing color " .. color_num .. (is_current_commit and " (current)" or "") .. (is_bold and " (bold)" or ""), vim.log.levels.INFO)
  
  -- Map to jj theme colors first
  local jj_mapped_color = jj_colors.map_256_to_jj_color(color_num)
  if jj_mapped_color then
    return jj_mapped_color
  end

  -- Handle current commit color mapping: when current commit uses regular colors (4,5,6), 
  -- map them to bright versions (12,13,14)
  if is_current_commit then
    if color_num == 4 then
      color_num = 12  -- Map regular blue to bright blue
    elseif color_num == 5 then
      color_num = 13  -- Map regular magenta to bright magenta  
    elseif color_num == 6 then
      color_num = 14  -- Map regular cyan to bright cyan
    end
  end

  -- Color mappings based on actual jj output
  local default_mappings = {
    [1] = '#ff6b6b',   -- red (conflicts)
    [2] = '#51cf66',   -- green ((empty) text)  
    [3] = '#feca57',   -- yellow (author)
    [4] = '#74b9ff',   -- blue (commit ID - regular commits)
    [5] = '#fd79a8',   -- magenta (change ID - regular commits)
    [6] = '#55efc4',   -- cyan (timestamps - regular commits)
    [8] = '#666666',   -- bright black (gray/dim text)
    [11] = '#fffa65',  -- bright yellow
    [12] = '#89CFF0',  -- bright blue (commit ID - current commit)
    [13] = '#FF6EC7',  -- bright magenta (change ID - current commit) 
    [14] = '#40E0D0',  -- bright cyan (timestamps - current commit)
    [15] = '#ffffff',  -- bright white
  }
  
  return default_mappings[color_num]
end

M.strip_ansi = function(text)
  return text:gsub('\27%[[%d;]*m', '')
end


return M

