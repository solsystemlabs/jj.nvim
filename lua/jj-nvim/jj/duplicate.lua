local M = {}

local command_utils = require('jj-nvim.jj.command_utils')
local commands = require('jj-nvim.jj.commands')

-- Core duplicate operation
M.duplicate = function(revsets, options)
  options = options or {}
  local cmd_args = { 'duplicate' }

  -- Add revsets (commits to duplicate)
  if revsets then
    if type(revsets) == 'string' then
      table.insert(cmd_args, revsets)
    elseif type(revsets) == 'table' then
      for _, revset in ipairs(revsets) do
        table.insert(cmd_args, revset)
      end
    end
  end
  -- If no revsets provided, jj duplicate defaults to @

  -- Add destination options (only one should be specified)
  if options.destination then
    table.insert(cmd_args, '--destination')
    if type(options.destination) == 'table' then
      for _, dest in ipairs(options.destination) do
        table.insert(cmd_args, dest)
      end
    else
      table.insert(cmd_args, options.destination)
    end
  elseif options.insert_after then
    table.insert(cmd_args, '--insert-after')
    if type(options.insert_after) == 'table' then
      for _, after in ipairs(options.insert_after) do
        table.insert(cmd_args, after)
      end
    else
      table.insert(cmd_args, options.insert_after)
    end
  elseif options.insert_before then
    table.insert(cmd_args, '--insert-before')
    if type(options.insert_before) == 'table' then
      for _, before in ipairs(options.insert_before) do
        table.insert(cmd_args, before)
      end
    else
      table.insert(cmd_args, options.insert_before)
    end
  end

  return command_utils.execute_with_error_handling(cmd_args, "duplicate commit", { silent = options.silent })
end

-- Duplicate the specified commit
M.duplicate_commit = function(commit, options)
  if not commit then
    vim.notify("No commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Get commit change ID
  local change_id, err = command_utils.get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local display_id = command_utils.get_short_display_id(commit, change_id)

  -- Build duplicate options
  local duplicate_options = { silent = options.silent }

  -- Add target options if specified
  if options.destination then
    duplicate_options.destination = options.destination
  elseif options.insert_after then
    duplicate_options.insert_after = options.insert_after
  elseif options.insert_before then
    duplicate_options.insert_before = options.insert_before
  end

  local result, exec_err = M.duplicate(change_id, duplicate_options)
  if not result then
    local error_msg = exec_err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot duplicate - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    end

    vim.notify(string.format("Failed to duplicate commit: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Determine success message based on options
  local action_desc = "Duplicated"
  if options.destination then
    action_desc = "Duplicated to destination"
  elseif options.insert_after then
    action_desc = "Duplicated after target"
  elseif options.insert_before then
    action_desc = "Duplicated before target"
  end

  vim.notify(string.format("%s commit %s", action_desc, display_id), vim.log.levels.INFO)
  return true
end

-- Duplicate multiple commits
M.duplicate_multiple_commits = function(selected_commit_ids, options)
  -- Validate multiple commits
  local valid_commits, invalid_commits, err = command_utils.validate_multiple_commits(
    selected_commit_ids,
    { allow_root = true } -- Allow duplicating root commit
  )

  if err then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  -- Report invalid commits
  if #invalid_commits > 0 then
    vim.notify(string.format("Cannot duplicate: %s", table.concat(invalid_commits, ", ")), vim.log.levels.WARN)
    if #valid_commits == 0 then
      return false
    end
  end

  options = options or {}

  -- Get change IDs for all valid commits
  local change_ids = {}
  for _, commit in ipairs(valid_commits) do
    local change_id, change_err = command_utils.get_change_id(commit)
    if change_id then
      table.insert(change_ids, change_id)
    else
      vim.notify(string.format("Failed to get change ID for commit: %s", change_err), vim.log.levels.ERROR)
      return false
    end
  end

  -- Build duplicate options
  local duplicate_options = { silent = options.silent }

  -- Add target options if specified
  if options.destination then
    duplicate_options.destination = options.destination
  elseif options.insert_after then
    duplicate_options.insert_after = options.insert_after
  elseif options.insert_before then
    duplicate_options.insert_before = options.insert_before
  end

  local result, exec_err = M.duplicate(change_ids, duplicate_options)
  if not result then
    local error_msg = exec_err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "One or more commits not found - they may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot duplicate - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    end

    vim.notify(string.format("Failed to duplicate commits: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Determine success message based on options
  local action_desc = "Duplicated"
  if options.destination then
    action_desc = "Duplicated to destination"
  elseif options.insert_after then
    action_desc = "Duplicated after target"
  elseif options.insert_before then
    action_desc = "Duplicated before target"
  end

  local commit_count = #change_ids
  vim.notify(string.format("%s %d commit%s", action_desc, commit_count, commit_count > 1 and "s" or ""), vim.log.levels.INFO)
  return true
end

-- Duplicate multiple commits asynchronously
M.duplicate_multiple_commits_async = function(selected_commit_ids, options, callback)
  if not selected_commit_ids or #selected_commit_ids == 0 then
    vim.notify("No commits selected for duplication", vim.log.levels.WARN)
    return
  end

  options = options or {}
  callback = callback or function() end

  -- Use change IDs directly (assume they're already validated)
  local change_ids = selected_commit_ids

  -- Determine action description for progress
  local action_desc = "Duplicating"
  if options.destination then
    action_desc = "Duplicating to destination"
  elseif options.insert_after then
    action_desc = "Duplicating after target"
  elseif options.insert_before then
    action_desc = "Duplicating before target"
  end

  -- Build command arguments
  local cmd_args = { 'duplicate' }
  
  -- Add all change IDs
  for _, change_id in ipairs(change_ids) do
    table.insert(cmd_args, change_id)
  end

  -- Add target options
  if options.destination then
    table.insert(cmd_args, '--destination')
    table.insert(cmd_args, options.destination)
  elseif options.insert_after then
    table.insert(cmd_args, '--insert-after')
    table.insert(cmd_args, options.insert_after)
  elseif options.insert_before then
    table.insert(cmd_args, '--insert-before')
    table.insert(cmd_args, options.insert_before)
  end

  -- Show progress indicator
  local timer = vim.loop.new_timer()
  local dots = ""
  local dot_count = 0

  timer:start(0, 1000, vim.schedule_wrap(function()
    dot_count = (dot_count + 1) % 4
    dots = string.rep(".", dot_count)
    vim.notify(string.format("%s %d commit(s)%s", action_desc, #change_ids, dots), vim.log.levels.INFO, { replace = true })
  end))

  command_utils.execute_with_error_handling_async(cmd_args, "duplicate commits", {}, function(result, err)
    timer:stop()
    timer:close()

    if result then
      -- Determine success message
      local success_desc = "Duplicated"
      if options.destination then
        success_desc = "Duplicated to destination"
      elseif options.insert_after then
        success_desc = "Duplicated after target"
      elseif options.insert_before then
        success_desc = "Duplicated before target"
      end

      local commit_count = #change_ids
      vim.notify(string.format("%s %d commit%s", success_desc, commit_count, commit_count > 1 and "s" or ""), vim.log.levels.INFO)
      callback(true)
    else
      callback(false)
    end
  end)
end

-- Show duplicate options menu
M.show_duplicate_options_menu = function(source_commit, parent_win_id)
  local inline_menu = require('jj-nvim.ui.inline_menu')
  local config = require('jj-nvim.config')

  -- Determine source display name
  local source_display = ""
  if source_commit then
    source_display = source_commit.short_change_id or source_commit.change_id:sub(1, 8)
  else
    source_display = "@"
  end

  -- Get duplicate menu keys from config
  local duplicate_keys = config.get('keybinds.menus.duplicate') or {
    quick = 'q',
    destination = 'd',
    insert_after = 'a',
    insert_before = 'b',
  }

  -- Define menu configuration using configurable keys
  local menu_config = {
    id = "duplicate",
    title = "Duplicate " .. source_display,
    items = {
      {
        key = duplicate_keys.quick,
        description = "Quick duplicate (in place)",
        action = "quick_duplicate",
      },
      {
        key = duplicate_keys.destination,
        description = "Duplicate to destination",
        action = "duplicate_destination",
      },
      {
        key = duplicate_keys.insert_after,
        description = "Duplicate after target",
        action = "duplicate_after",
      },
      {
        key = duplicate_keys.insert_before,
        description = "Duplicate before target",
        action = "duplicate_before",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_duplicate_options_selection(selected_item, source_commit)
    end,
    on_cancel = function()
      vim.notify("Duplicate cancelled", vim.log.levels.INFO)
    end
  })
end

-- Handle duplicate options menu selection
M.handle_duplicate_options_selection = function(selected_item, source_commit)
  local action = selected_item.action

  if action == "quick_duplicate" then
    -- Quick duplicate: duplicate commit in place (default jj duplicate behavior)
    local success = M.duplicate_commit(source_commit, {})
    if success then
      require('jj-nvim').refresh()
    end
  elseif action == "duplicate_destination" then
    -- Enter target selection mode for destination
    local window = require('jj-nvim.ui.window')
    window.enter_duplicate_target_selection_mode("destination", source_commit)
  elseif action == "duplicate_after" then
    -- Enter target selection mode for insert-after
    local window = require('jj-nvim.ui.window')
    window.enter_duplicate_target_selection_mode("insert_after", source_commit)
  elseif action == "duplicate_before" then
    -- Enter target selection mode for insert-before
    local window = require('jj-nvim.ui.window')
    window.enter_duplicate_target_selection_mode("insert_before", source_commit)
  end
end

return M