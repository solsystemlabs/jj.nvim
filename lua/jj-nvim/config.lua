local M = {}
local persistence = require('jj-nvim.utils.persistence')

M.defaults = {
  window = {
    width = 70,
    position = 'right',
    wrap = true, -- Re-enabled until we fix smart wrapping
    border = {
      enabled = true,
      style = 'left', -- 'none', 'single', 'double', 'rounded', 'thick', 'shadow', 'left'
      color = 'gray', -- 'gray', 'subtle', 'accent', 'muted' or hex color like '#555555'
    },
  },
  keymaps = {
    toggle = '<leader>jp',
    close = 'q',
    show_diff = '<CR>',
    edit_message = 'e',
    abandon = 'a',
    rebase = 'r',
    next_commit = 'j',
    prev_commit = 'k',
  },
  log = {
    format = 'short',
    limit = 100,
  },
  colors = {
    theme = 'auto', -- 'auto', 'gruvbox', 'catppuccin', 'nord', 'tokyo-night', 'onedark', 'default'
  },
  diff = {
    format = 'git', -- 'git', 'stat', 'color-words', 'name-only'
    split = 'horizontal', -- 'horizontal', 'vertical'
    size = 50, -- Size percentage for diff window
  }
}

M.options = {}
M.persistent_settings = {}

M.setup = function(opts)
  -- Load persistent settings from disk
  M.persistent_settings = persistence.load()

  -- Merge: defaults < persistent settings < user opts
  M.options = vim.tbl_deep_extend('force', M.defaults, M.persistent_settings, opts or {})
end

M.get = function(key)
  local keys = vim.split(key, '.', { plain = true })
  local value = M.options
  for _, k in ipairs(keys) do
    value = value[k]
    if value == nil then
      return nil
    end
  end
  return value
end

M.set = function(key, value)
  local keys = vim.split(key, '.', { plain = true })

  -- Update runtime options
  local current = M.options
  for i = 1, #keys - 1 do
    local k = keys[i]
    if current[k] == nil then
      current[k] = {}
    end
    current = current[k]
  end
  current[keys[#keys]] = value

  -- Update persistent settings
  current = M.persistent_settings
  for i = 1, #keys - 1 do
    local k = keys[i]
    if current[k] == nil then
      current[k] = {}
    end
    current = current[k]
  end
  current[keys[#keys]] = value

  -- Save to disk
  persistence.save(M.persistent_settings)
end

return M

