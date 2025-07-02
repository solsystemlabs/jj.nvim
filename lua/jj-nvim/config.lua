local M = {}
local persistence = require('jj-nvim.utils.persistence')

M.defaults = {
  window = {
    position = 'right',
    wrap = true, -- Re-enabled until we fix smart wrapping
    border = {
      enabled = true,
      style = 'left', -- 'none', 'single', 'double', 'rounded', 'thick', 'shadow', 'left'
    },
  },
  keymaps = {
    toggle = '<leader>jp',
    close = 'q',
    show_diff = '<CR>',
    edit_message = 'e',
    abandon = 'a',
    rebase = 'r',
    squash = 'x',
    split = 's',
    next_commit = 'j',
    prev_commit = 'k',
  },
  menus = {
    navigation = {
      next = 'j',
      prev = 'k',
      next_alt = '<Down>',
      prev_alt = '<Up>',
      select = '<CR>',
      cancel = '<Esc>',
      cancel_alt = 'q',
      back = '<BS>', -- submenu back navigation
    },
    commit = {
      quick = 'q',
      interactive = 'i',
      reset_author = 'r',
      custom_author = 'a',
      filesets = 'f',
    },
    squash = {
      quick = 'q',
      interactive = 'i',
      keep_emptied = 'k',
      custom_message = 'm',
    },
    split = {
      interactive = 'i',
      after = 'a',
      before = 'b',
    },
    rebase = {
      branch = 'b',
      source = 's',
      revisions = 'r',
      destination = 'd',
      insert_after = 'a',
      insert_before = 'f',
      skip_emptied = 'e',
    },
    bookmark = {
      create = 'c',
      delete = 'd',
      move = 'm',
      rename = 'r',
      list = 'l',
      toggle_filter = 't',
    },
    new_change = {
      quick = 'q',
      interactive = 'i',
      custom_message = 'm',
      after_commit = 'a',
      insert = 'n',
    },
  },
  log = {
    format = 'short',
    limit = 100,
    default_revset = 'all()', -- Default revset when opening jj log (e.g., 'all()', '::@', 'mine()')
    show_revset_in_title = true,
    revset_presets = {
      { name = 'All commits',            revset = 'all()' },
      { name = 'Ancestors of current',   revset = '::@' },
      { name = 'Parent of current',      revset = '@-' },
      { name = 'Last 50 commits',        revset = 'latest(all(), 50)' },
      { name = 'Since main branch',      revset = 'trunk()..' },
      { name = 'My commits',             revset = 'mine()' },
      { name = 'Commits with bookmarks', revset = 'bookmarks()' },
      { name = 'Merge commits',          revset = 'merges()' },
      { name = 'Recent (last week)',     revset = 'author_date(after:"1 week ago")' },
      { name = 'Conflicts',              revset = 'conflicts()' },
    },
  },
  diff = {
    format = 'git',       -- 'git', 'stat', 'color-words', 'name-only'
    display = 'split',    -- 'split', 'float'
    split = 'horizontal', -- 'horizontal', 'vertical' (for split mode)
    size = 50,            -- Size percentage for diff window
    float = {
      width = 0.8,        -- Floating window width as percentage of screen
      height = 0.8,       -- Floating window height as percentage of screen
      border = 'rounded', -- 'none', 'single', 'double', 'rounded', 'solid', 'shadow'
    },
  },
  status = {
    display = 'split',    -- 'split', 'float'
    split = 'horizontal', -- 'horizontal', 'vertical' (for split mode)
    size = 50,            -- Size percentage for status window
    float = {
      width = 0.8,        -- Floating window width as percentage of screen
      height = 0.8,       -- Floating window height as percentage of screen
      border = 'rounded', -- 'none', 'single', 'double', 'rounded', 'solid', 'shadow'
    },
  },
  interactive = {
    float = {
      width = 0.9,        -- Floating terminal width as percentage of screen
      height = 0.8,       -- Floating terminal height as percentage of screen
      border = 'rounded', -- 'none', 'single', 'double', 'rounded', 'solid', 'shadow'
    },
    auto_close = true,    -- Auto-close terminal on successful command completion
    error_persist = true, -- Keep terminal open on error for user to see output
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

-- Force reload the config (clears module cache and re-initializes)
M.reload = function(opts)
  -- Clear this module from cache to pick up any changes to defaults
  package.loaded['jj-nvim.config'] = nil
  package.loaded['jj-nvim.utils.persistence'] = nil

  -- Reload the module
  local reloaded_config = require('jj-nvim.config')

  -- Re-setup with the same options
  reloaded_config.setup(opts)

  -- Copy the reloaded state back to this module
  M.defaults = reloaded_config.defaults
  M.options = reloaded_config.options
  M.persistent_settings = reloaded_config.persistent_settings

  return reloaded_config
end

M.get = function(key)
  local keys = vim.split(key, '.', { plain = true })

  -- First try to get from options (if setup() has been called)
  local value = M.options
  for _, k in ipairs(keys) do
    value = value[k]
    if value == nil then
      break
    end
  end

  -- If not found in options or options is empty, fall back to defaults
  if value == nil then
    value = M.defaults
    for _, k in ipairs(keys) do
      value = value[k]
      if value == nil then
        return nil
      end
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

-- Get window width from persistence (not from config)
M.get_window_width = function()
  -- Check persistent settings first
  if M.persistent_settings.window and M.persistent_settings.window.width then
    return M.persistent_settings.window.width
  end

  -- Default to 70 if no persisted width exists
  return 70
end

-- Convenience function to persist window width
M.persist_window_width = function(width)
  if not M.persistent_settings.window then
    M.persistent_settings.window = {}
  end
  M.persistent_settings.window.width = width
  persistence.save(M.persistent_settings)
end

-- Debug function to show current config state
M.debug = function()
  vim.notify("=== Config Debug ===", vim.log.levels.INFO)
  vim.notify("Setup called: " .. (next(M.options) and "YES" or "NO"), vim.log.levels.INFO)
  vim.notify("Default nav next: " .. (M.defaults.menus.navigation.next), vim.log.levels.INFO)
  vim.notify("Resolved nav next: " .. (M.get('menus.navigation.next') or 'nil'), vim.log.levels.INFO)
  vim.notify("squash key: " .. (M.get('keymaps.squash') or 'nil'), vim.log.levels.INFO)
  vim.notify("split key: " .. (M.get('keymaps.split') or 'nil'), vim.log.levels.INFO)
end

return M
