local M = {}

-- Setup common navigation keymaps used in both target selection and multi-select modes
M.setup_common_navigation = function(buf_id, win_id, navigation, opts, update_callback)
  local nav_opts = opts or {}
  
  -- Basic j/k navigation  
  vim.keymap.set('n', 'j', function()
    navigation.next_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)
  
  vim.keymap.set('n', 'k', function()
    navigation.prev_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  -- Additional navigation (centered)
  vim.keymap.set('n', 'J', function()
    navigation.next_commit_centered(win_id)
    if update_callback then update_callback() end
  end, nav_opts)
  
  vim.keymap.set('n', 'K', function()
    navigation.prev_commit_centered(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  -- Go to specific commits
  vim.keymap.set('n', 'gg', function()
    navigation.goto_first_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)
  
  vim.keymap.set('n', 'G', function()
    navigation.goto_last_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)
  
  vim.keymap.set('n', '@', function()
    navigation.goto_current_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)
end

-- Setup common disabled action keymaps for special modes
M.setup_disabled_actions = function(buf_id, message, opts)
  local disabled_opts = opts or {}
  
  vim.keymap.set('n', 'q', function() 
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)
  
  vim.keymap.set('n', 'n', function() 
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)
  
  vim.keymap.set('n', 'e', function() 
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)
  
  vim.keymap.set('n', 'a', function() 
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)
end

-- Remove conflicting keymaps before setting up new mode
M.clear_conflicting_keymaps = function(buf_id)
  pcall(vim.keymap.del, 'n', '<CR>', { buffer = buf_id })
  pcall(vim.keymap.del, 'n', '<Esc>', { buffer = buf_id })
  pcall(vim.keymap.del, 'n', '<Space>', { buffer = buf_id })
end

return M