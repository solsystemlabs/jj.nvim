local M = {}

M.defaults = {
  window = {
    width = 60,
    position = 'right',
  },
  keymaps = {
    toggle = '<leader>jl',
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
  }
}

M.options = {}

M.setup = function(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
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

return M