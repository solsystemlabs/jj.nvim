local M = {}

local ansi = require('jj-nvim.utils.ansi')

M.create = function(content)
  local buf_id = vim.api.nvim_create_buf(false, true)
  
  vim.api.nvim_buf_set_name(buf_id, 'JJ Log')
  
  ansi.setup_highlights()
  
  local lines = vim.split(content, '\n', { plain = true })
  M.set_lines_with_highlights(buf_id, lines)
  
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', true)
  vim.api.nvim_buf_set_option(buf_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf_id, 'filetype', 'jj-log')
  
  return buf_id
end

M.set_lines_with_highlights = function(buf_id, lines)
  local clean_lines = {}
  local highlights = {}
  
  -- Debug: Check if we have ANSI codes in the input
  local has_ansi = false
  local debug_line = ""
  for _, line in ipairs(lines) do
    if line:find('\27%[') then
      has_ansi = true
      debug_line = line
      break
    end
  end
  
  -- Debug: Log what we found (remove this after testing)
  -- vim.notify("ANSI found: " .. tostring(has_ansi), vim.log.levels.INFO)
  
  if not has_ansi then
    -- No ANSI codes found, just set lines normally
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    return
  end
  
  for line_nr, line in ipairs(lines) do
    local segments = ansi.parse_ansi_line(line)
    local clean_line = ansi.strip_ansi(line)
    
    table.insert(clean_lines, clean_line)
    
    local col = 0
    for _, segment in ipairs(segments) do
      if segment.highlight and segment.text ~= '' then
        table.insert(highlights, {
          line = line_nr - 1,
          col_start = col,
          col_end = col + #segment.text,
          hl_group = segment.highlight
        })
      end
      col = col + #segment.text
    end
  end
  
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, clean_lines)
  
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf_id, -1, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end
end

M.update = function(buf_id, content)
  if not vim.api.nvim_buf_is_valid(buf_id) then
    return false
  end
  
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', false)
  
  vim.api.nvim_buf_clear_namespace(buf_id, -1, 0, -1)
  
  local lines = vim.split(content, '\n', { plain = true })
  M.set_lines_with_highlights(buf_id, lines)
  
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf_id, 'readonly', true)
  
  return true
end

return M