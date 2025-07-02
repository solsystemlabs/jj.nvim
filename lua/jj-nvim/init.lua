local M = {}

local config = require('jj-nvim.config')
local window = require('jj-nvim.ui.window')
local buffer = require('jj-nvim.ui.buffer')
local parser = require('jj-nvim.core.parser')
local jj_log = require('jj-nvim.jj.log')
local error_handler = require('jj-nvim.utils.error_handler')
local keymap_registry = require('jj-nvim.utils.keymap_registry')

M.setup = function(opts)
  config.setup(opts or {})
  -- Initialize keymap registry with the configured options
  keymap_registry.initialize(config)
end

-- Reload config and re-initialize all systems (useful for config changes)
M.reload_config = function(opts)
  -- Reload the config module to pick up changes to defaults
  local reloaded_config = config.reload(opts)
  
  -- Re-initialize keymap registry with fresh config
  keymap_registry.initialize(reloaded_config)
  
  -- Refresh the jj-nvim window if it's open to pick up new keybinds
  if window.is_open() then
    M.refresh()
    -- Re-setup keymaps to pick up config changes
    window.setup_keymaps()
  end
  
  vim.notify("jj-nvim config reloaded", vim.log.levels.INFO)
end

M.toggle = function()
  if window.is_open() then
    M.close()
  else
    M.show_log()
  end
end

-- Current revset stored as module variable for session persistence
local current_revset = nil

M.show_log = function(revset)
  -- Use provided revset or current_revset or default from config
  local selected_revset = revset or current_revset or config.get('log.default_revset')
  current_revset = selected_revset
  
  -- Use separate graph + data parsing system with revset
  local commits, err = parser.parse_commits_with_separate_graph(selected_revset)
  if error_handler.handle_jj_error(err, "parse commits") then return end
  if error_handler.handle_empty_result(commits, "No commits found. Is this a jj repository?") then return end

  -- If window is already open, update the existing buffer
  if window.is_open() then
    local success = buffer.update_from_fresh_data(commits, selected_revset)
    if not success then
      vim.notify("Failed to update jj log buffer", vim.log.levels.ERROR)
    end
  else
    -- Create new buffer and window
    local buf_id = buffer.create_from_commits(commits, selected_revset)
    if error_handler.handle_empty_result(buf_id, "Failed to create jj log buffer") then return end
    
    window.open_with_buffer(buf_id)
  end
end

-- Legacy method for backward compatibility
M.show_log_legacy = function()
  local log_content = jj_log.get_log()
  if error_handler.handle_empty_result(log_content, "Failed to get jj log. Is this a jj repository?") then return end
  
  window.open(log_content)
end

M.close = function()
  window.close()
end

-- Centralized refresh function that all operations should call
-- This ensures the renderer collects fresh data every time
M.refresh = function()
  -- Only refresh if window is open
  if not window.is_open() then
    return false
  end
  
  -- Use current revset for refresh
  local selected_revset = current_revset or config.get('log.default_revset')
  
  -- Collect fresh commit data and status information
  local commits, err = parser.parse_commits_with_separate_graph(selected_revset)
  if error_handler.handle_jj_error(err, "refresh commits") then 
    return false 
  end
  
  commits = commits or {}
  
  -- Update the buffer with fresh data - this will automatically collect
  -- fresh status information including current working copy ID
  local success = buffer.update_from_fresh_data(commits, selected_revset)
  
  return success
end

-- New functions for revset operations
-- Validate a revset by doing a quick test parse
local function validate_revset(revset)
  local commands = require('jj-nvim.jj.commands')
  local test_args = { 'log', '--template', 'commit_id', '--no-graph', '--limit', '1' }
  if revset and revset ~= 'all()' then
    table.insert(test_args, '-r')
    table.insert(test_args, revset)
  end
  
  local _, err = commands.execute(test_args, { silent = true })
  return err == nil, err
end

M.set_revset = function(revset)
  -- Validate the revset first
  local valid, err = validate_revset(revset)
  if not valid then
    vim.notify("Invalid revset '" .. revset .. "': " .. (err or "Unknown error"), vim.log.levels.ERROR)
    return false
  end
  
  current_revset = revset
  if window.is_open() then
    M.show_log(revset)
    -- Reset cursor to safe position after changing revsets
    local navigation = require('jj-nvim.ui.navigation')
    local win_id = window.get_current_win_id()
    if win_id then
      navigation.goto_first_commit_after_status(win_id)
    end
  end
  return true
end

M.get_current_revset = function()
  return current_revset or config.get('log.default_revset')
end

M.show_revset_menu = function()
  local inline_menu = require('jj-nvim.ui.inline_menu')
  local window = require('jj-nvim.ui.window')
  local presets = config.get('log.revset_presets') or {}
  
  if not window.is_open() then
    vim.notify("Open JJ log window first", vim.log.levels.WARN)
    return
  end
  
  local menu_items = {}
  for i, preset in ipairs(presets) do
    table.insert(menu_items, {
      key = tostring(i),
      text = preset.name,
      description = preset.revset,
      action = function() M.set_revset(preset.revset) end
    })
  end
  
  -- Add custom revset option
  table.insert(menu_items, {
    key = 'c',
    text = 'Enter custom revset...',
    description = 'Type a custom revset expression',
    action = function()
      local input = vim.fn.input('Enter revset: ', M.get_current_revset())
      if input and input ~= '' then
        M.set_revset(input)
      end
    end
  })
  
  local menu_config = {
    title = 'Select Revset',
    items = menu_items
  }
  
  -- Get the current window ID directly from window module
  local parent_win = window.get_current_win_id()
  if not parent_win then
    vim.notify("Could not find JJ log window", vim.log.levels.WARN)
    return
  end
  
  local callbacks = {
    on_select = function(item)
      if item.action then
        item.action()
      end
    end
  }
  
  inline_menu.show(parent_win, menu_config, callbacks)
end

-- Create vim commands for config reloading
vim.api.nvim_create_user_command('JJReloadConfig', function()
  M.reload_config()
end, { desc = 'Reload jj-nvim configuration' })

return M

