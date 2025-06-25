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
  elseif stripped_line:match('^│') then
    -- Line starts with │ - check if it has bold formatting (indicates current commit context)
    is_current_commit = line:find('\27%[1m') ~= nil
  end

  -- Debug: uncomment to see current commit detection
  -- if is_current_commit then
  --   print("CURRENT COMMIT DETECTED: " .. stripped_line:sub(1, 20))
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
      -- Convert 256-color number to hex color
      local hex_color = M.color_256_to_hex(attrs.fg, is_current_commit)
      hl_attrs.fg = hex_color
      -- Debug: uncomment to see color mappings
      -- print("Color " .. attrs.fg .. " -> " .. hex_color .. (is_current_commit and " (current)" or ""))
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

M.color_256_to_hex = function(color_num, is_current_commit)
  -- Special case: color 3 (author email and description) on current commit should be bright_yellow
  if color_num == 3 and is_current_commit then
    local bright_yellow = jj_colors.get_current_theme_color('bright_yellow')
    local fallback_yellow = jj_colors.map_256_to_jj_color(3)
    -- Debug: uncomment to see color override
    -- print("USING BRIGHT_YELLOW for color 3: " .. (bright_yellow or "nil") .. " fallback: " .. (fallback_yellow or "nil"))
    return bright_yellow or fallback_yellow
  end

  -- Map to jj theme colors
  local jj_mapped_color = jj_colors.map_256_to_jj_color(color_num)
  if jj_mapped_color then
    return jj_mapped_color
  end

  -- For unmapped colors, return nil (no highlighting)
  return nil
end

M.strip_ansi = function(text)
  return text:gsub('\27%[[%d;]*m', '')
end

return M