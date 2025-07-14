local M = {}

local command_utils = require('jj-nvim.jj.command_utils')
local commands = require('jj-nvim.jj.commands')

-- Interactive squash
M.squash_interactive = function(commit_id, options)
  options = options or {}
  local cmd_args = { 'squash', '--interactive' }

  if commit_id and commit_id ~= "" then
    table.insert(cmd_args, '-r')
    table.insert(cmd_args, commit_id)
  end

  return commands.execute_interactive_with_immutable_prompt(cmd_args, options)
end

-- Squash source revision into target revision
M.squash = function(target_revision, options)
  if not target_revision or target_revision == "" then
    return nil, "No target revision provided"
  end

  options = options or {}
  local cmd_args = { 'squash' }

  -- Add source revision if provided, otherwise defaults to working copy
  if options.from_revision then
    table.insert(cmd_args, '--from')
    table.insert(cmd_args, options.from_revision)
  end

  -- Add target revision
  table.insert(cmd_args, '--into')
  table.insert(cmd_args, target_revision)

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  -- Add interactive mode
  if options.interactive then
    table.insert(cmd_args, '--interactive')
  end

  -- Add diff tool for interactive mode
  if options.tool then
    table.insert(cmd_args, '--tool')
    table.insert(cmd_args, options.tool)
  end

  -- Use destination message
  if options.use_destination_message then
    table.insert(cmd_args, '--use-destination-message')
  end

  -- For non-interactive squash, default to using destination message if no other options specified
  if not options.interactive and not options.message and not options.use_destination_message then
    table.insert(cmd_args, '--use-destination-message')
  end

  -- Keep emptied source
  if options.keep_emptied then
    table.insert(cmd_args, '--keep-emptied')
  end

  -- Add filesets/paths if specified
  if options.filesets and #options.filesets > 0 then
    for _, fileset in ipairs(options.filesets) do
      table.insert(cmd_args, fileset)
    end
  end

  -- Use interactive execution for interactive mode
  if options.interactive then
    -- Pass through callback options for interactive terminal
    local interactive_options = {
      on_success = options.on_success,
      on_error = options.on_error,
      on_cancel = options.on_cancel,
      cwd = options.cwd,
    }
    return commands.execute_interactive_with_immutable_prompt(cmd_args, interactive_options)
  else
    return commands.execute_with_immutable_prompt(cmd_args, { silent = options.silent })
  end
end

-- Squash current commit into target commit
M.squash_into_commit = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Don't allow squashing into root commit
  if target_commit.root then
    vim.notify("Cannot squash into the root commit", vim.log.levels.WARN)
    return false
  end

  local target_change_id, err = command_utils.get_change_id(target_commit)
  if not target_change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local target_display_id = command_utils.get_short_display_id(target_commit, target_change_id)

  -- Handle interactive mode with callbacks
  if options.interactive then
    -- Add callbacks for interactive mode
    options.on_success = function()
      vim.notify(string.format("Interactive squash into %s completed", target_display_id), vim.log.levels.INFO)
      -- Buffer refresh is handled automatically by interactive terminal
    end
    options.on_error = function(exit_code)
      -- Error message already shown by interactive terminal
    end
    options.on_cancel = function()
      vim.notify("Interactive squash cancelled", vim.log.levels.INFO)
    end

    -- Execute interactive squash
    local success = M.squash(target_change_id, options)
    if not success then
      vim.notify("Failed to start interactive squash", vim.log.levels.ERROR)
      return false
    end
    return true -- Interactive command started successfully
  else
    -- Non-interactive squash
    local result, exec_err = M.squash(target_change_id, options)
    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Commit not found - it may have been abandoned or modified"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Cannot squash - would create a cycle in commit graph"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      end

      vim.notify(string.format("Failed to squash into commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify(string.format("Squashed into %s", target_display_id), vim.log.levels.INFO)
    return true
  end
end

-- Squash current commit into bookmark target
M.squash_into_bookmark = function(bookmark, options)
  if not bookmark then
    vim.notify("No bookmark specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Use bookmark name as target revision
  local target_revision = bookmark.name
  if not target_revision or target_revision == "" then
    vim.notify("Invalid bookmark: missing name", vim.log.levels.ERROR)
    return false
  end

  local bookmark_display = bookmark.display_name or bookmark.name

  -- Handle interactive mode with callbacks
  if options.interactive then
    -- Add callbacks for interactive mode
    options.on_success = function()
      vim.notify(string.format("Interactive squash into bookmark '%s' completed", bookmark_display), vim.log.levels.INFO)
      -- Buffer refresh is handled automatically by interactive terminal
    end
    options.on_error = function(exit_code)
      -- Error message already shown by interactive terminal
    end
    options.on_cancel = function()
      vim.notify("Interactive squash cancelled", vim.log.levels.INFO)
    end

    -- Execute interactive squash
    local success = M.squash(target_revision, options)
    if not success then
      vim.notify("Failed to start interactive squash", vim.log.levels.ERROR)
      return false
    end
    return true -- Interactive command started successfully
  else
    -- Non-interactive squash
    local result, exec_err = M.squash(target_revision, options)
    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Bookmark not found - it may have been deleted or modified"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Cannot squash - would create a cycle in commit graph"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      end

      vim.notify(string.format("Failed to squash into bookmark: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify(string.format("Squashed into bookmark '%s'", bookmark_display), vim.log.levels.INFO)
    return true
  end
end

-- Show squash options menu after target selection
M.show_squash_options_menu = function(target, target_type, parent_win_id, source_commit)
  local inline_menu = require('jj-nvim.ui.inline_menu')
  local config = require('jj-nvim.config')

  -- Determine target display name
  local target_display = ""
  if target_type == "commit" then
    target_display = target.short_change_id or target.change_id:sub(1, 8)
  elseif target_type == "bookmark" then
    target_display = "bookmark '" .. (target.display_name or target.name) .. "'"
  end

  -- Determine source display name
  local source_display = ""
  if source_commit then
    source_display = source_commit.short_change_id or source_commit.change_id:sub(1, 8)
  else
    source_display = "@"
  end

  -- Get squash menu keys from config
  local squash_keys = config.get('keybinds.menus.squash') or config.get('menus.squash') or {
    quick = 'q',
    interactive = 'i',
    keep_emptied = 'k',
    custom_message = 'm',
  }

  -- Define menu configuration using configurable keys
  local menu_config = {
    id = "squash",
    title = "Squash " .. source_display .. " into " .. target_display,
    items = {
      {
        key = squash_keys.quick,
        description = "Quick squash (standard)",
        action = "quick_squash",
      },
      {
        key = squash_keys.interactive,
        description = "Interactive squash",
        action = "interactive_squash",
      },
      {
        key = squash_keys.custom_message,
        description = "Use destination message & keep source",
        action = "use_dest_keep_squash",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_squash_options_selection(selected_item, target, target_type, source_commit)
    end,
    on_cancel = function()
      vim.notify("Squash cancelled", vim.log.levels.INFO)
    end
  })
end

-- Handle squash options menu selection
M.handle_squash_options_selection = function(selected_item, target, target_type, source_commit)
  local options = {}

  -- Configure options based on selection
  if selected_item.action == "interactive_squash" then
    options.interactive = true
  elseif selected_item.action == "use_dest_keep_squash" then
    options.use_destination_message = true
    options.keep_emptied = true
  elseif selected_item.action == "quick_squash" then
    -- For quick squash, we want to squash @ into @- (current into parent)
    -- This means we don't use the selected target, but use @- as target
    options.quick_squash = true
  end

  -- Add source commit to options if provided
  if source_commit then
    local source_change_id, err = command_utils.get_change_id(source_commit)
    if source_change_id then
      options.from_revision = source_change_id
    else
      vim.notify("Failed to get source commit ID: " .. (err or "Unknown error"), vim.log.levels.ERROR)
      return
    end
  else
    -- Fallback to current working copy if no source commit specified
    -- This shouldn't happen in normal workflow, but provides safety
    vim.notify("Warning: No source commit specified, using working copy (@)", vim.log.levels.WARN)
  end

  local success = false

  -- Execute squash based on selection type
  if options.quick_squash then
    -- For quick squash, use the simple command: jj squash -t @- -u
    -- This is always @ -> @- regardless of cursor position, as it's a specific working copy operation
    local commands = require('jj-nvim.jj.commands')
    local result, exec_err = commands.execute({ 'squash', '-t', '@-', '-u' })
    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Parent commit not found"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Cannot squash - would create a cycle in commit graph"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      end
      vim.notify(string.format("Failed to quick squash: %s", error_msg), vim.log.levels.ERROR)
      success = false
    else
      vim.notify("Quick squash completed", vim.log.levels.INFO)
      success = true
    end
  else
    -- Execute squash based on target type
    if target_type == "commit" then
      success = M.squash_into_commit(target, options)
    elseif target_type == "bookmark" then
      success = M.squash_into_bookmark(target, options)
    end
  end

  if success then
    -- Refresh buffer to show changes
    require('jj-nvim').refresh()
  end
end

return M