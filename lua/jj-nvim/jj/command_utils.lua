local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_utils = require('jj-nvim.core.commit')

-- Helper function to get change ID from commit
-- Extracted from abandon.lua, edit.lua, squash.lua, rebase.lua, actions.lua
M.get_change_id = function(commit)
  if not commit then
    return nil, "No commit provided"
  end

  local change_id = commit_utils.get_id(commit)
  if not change_id or change_id == "" then
    return nil, "Invalid commit: missing change ID"
  end

  return change_id, nil
end

-- Helper function to get short display ID from commit
-- Extracted from abandon.lua, edit.lua, squash.lua, rebase.lua, actions.lua
M.get_short_display_id = function(commit, change_id)
  return commit_utils.get_display_id(commit)
end

-- Helper function to handle command execution with common error patterns
-- Extracted and standardized from abandon.lua, edit.lua, and others
M.execute_with_error_handling = function(cmd_args, error_context, options)
  options = options or {}

  local result, err
  if options.interactive then
    result, err = commands.execute_interactive_with_immutable_prompt(cmd_args, options)
  else
    result, err = commands.execute_with_immutable_prompt(cmd_args, options)
  end

  if not result then
    local error_msg = err or "Unknown error"

    -- Common error pattern mapping
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot create change - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("duplicate") then
      error_msg = "Duplicate change IDs specified"
    elseif error_msg:find("immutable") then
      error_msg = "Cannot modify immutable commit (has been pushed to remote)"
    elseif error_msg:find("conflict") then
      error_msg = "Operation would create conflicts - resolve manually"
    elseif error_msg:find("ambiguous") then
      error_msg = "Ambiguous commit ID - please specify more characters"
    end

    if not options.silent then
      vim.notify(string.format("Failed to %s: %s", error_context, error_msg), vim.log.levels.ERROR)
    end
    return false, error_msg
  end

  return result, nil
end

-- Async version of execute_with_error_handling
M.execute_with_error_handling_async = function(cmd_args, error_context, options, callback)
  options = options or {}
  callback = callback or function() end

  local commands = require('jj-nvim.jj.commands')

  -- Handle interactive commands (these can't be async)
  if options.interactive then
    -- For interactive commands, we still need to use the sync version
    -- but we can wrap it in vim.schedule to make it non-blocking
    vim.schedule(function()
      local result, err = M.execute_with_error_handling(cmd_args, error_context, options)
      callback(result, err)
    end)
    return
  end

  -- For non-interactive commands, use async execution
  commands.execute_async(cmd_args, { ignore_immutable = options.ignore_immutable }, function(result, err)
    if not result then
      local error_msg = err or "Unknown error"

      -- Apply common error pattern mapping
      if error_msg:find("Commit .* is immutable") then
        error_msg = "Cannot modify immutable commit (try --ignore-immutable flag)"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Operation would create a cycle in the commit graph"
      elseif error_msg:find("Commit .* has conflicts") then
        error_msg = "Commit has conflicts that need to be resolved"
      elseif error_msg:find("No such revision") then
        error_msg = "Commit not found or invalid revision"
      end

      if not options.silent then
        vim.notify(string.format("Failed to %s: %s", error_context, error_msg), vim.log.levels.ERROR)
      end
      callback(false, error_msg)
      return
    end

    callback(result, nil)
  end)
end

-- Validate commit for common operations
-- Consolidates validation logic scattered across command modules
M.validate_commit = function(commit, options)
  options = options or {}

  if not commit then
    return false, "No commit provided"
  end

  -- Check if root commit (usually not allowed for most operations)
  if not options.allow_root and commit.root then
    return false, "Cannot perform operation on root commit"
  end

  -- Check if current working copy (most operations allow this, so default to true)
  local allow_current = options.allow_current
  if allow_current == nil then allow_current = true end -- Default to allowing current
  if not allow_current and commit:is_current() then
    return false, "Cannot perform operation on current working copy"
  end

  -- Validate change ID exists
  local change_id, err = M.get_change_id(commit)
  if not change_id then
    return false, err
  end

  return true, nil
end

-- Helper function to confirm operations with user
-- Standardizes confirmation patterns across modules
M.confirm_operation = function(message, callback, options)
  options = options or {}
  local choices = options.choices or { 'Yes', 'No' }
  local default_choice = options.default or #choices -- Default to last choice (usually "No")

  vim.ui.select(choices, {
    prompt = message,
  }, function(choice)
    if choice == choices[1] then -- First choice is usually "Yes"
      if callback then callback(true) end
    else
      if options.cancel_message then
        vim.notify(options.cancel_message, vim.log.levels.INFO)
      end
      if callback then callback(false) end
    end
  end)
end

-- Helper function to get all commits from buffer
-- Consolidates buffer access pattern used across modules
M.get_all_commits = function()
  local buffer = require('jj-nvim.ui.buffer')
  local all_commits = buffer.get_commits()
  if not all_commits then
    return nil, "Failed to get commits from buffer"
  end
  return all_commits, nil
end

-- Helper function to find commit by ID
-- Used in multi-commit operations
M.find_commit_by_id = function(commit_id, commits)
  commits = commits or M.get_all_commits()
  if not commits then
    return nil, "No commits available"
  end

  for _, commit in ipairs(commits) do
    local c_id = commit.change_id or commit.short_change_id
    if c_id == commit_id then
      return commit, nil
    end
  end

  return nil, "Commit not found: " .. (commit_id or "unknown")
end

-- Helper function to validate multiple commits for operations
-- Used in abandon_multiple_commits and similar functions
M.validate_multiple_commits = function(commit_ids, validation_options)
  validation_options = validation_options or {}

  if not commit_ids or #commit_ids == 0 then
    return nil, nil, "No commits selected"
  end

  local all_commits, err = M.get_all_commits()
  if not all_commits then
    return nil, nil, err
  end

  local valid_commits = {}
  local invalid_commits = {}

  for _, commit_id in ipairs(commit_ids) do
    local commit, find_err = M.find_commit_by_id(commit_id, all_commits)

    if commit then
      local is_valid, validation_err = M.validate_commit(commit, validation_options)
      if is_valid then
        table.insert(valid_commits, commit)
      else
        local display_id = M.get_short_display_id(commit)
        table.insert(invalid_commits, string.format("%s (%s)", display_id, validation_err))
      end
    else
      table.insert(invalid_commits, string.format("%s (not found)", commit_id:sub(1, 8)))
    end
  end

  return valid_commits, invalid_commits, nil
end

-- Helper function to build commit summaries for confirmations
-- Standardizes the display format across operations
M.build_commit_summaries = function(commits, max_display)
  max_display = max_display or 5
  local commit_summaries = {}

  for _, commit in ipairs(commits) do
    local display_id = M.get_short_display_id(commit)
    local desc = commit:get_short_description()
    table.insert(commit_summaries, string.format("  %s: %s", display_id, desc))
  end

  if #commit_summaries <= max_display then
    return table.concat(commit_summaries, "\n")
  else
    local visible_summaries = {}
    for i = 1, max_display - 1 do
      table.insert(visible_summaries, commit_summaries[i])
    end
    table.insert(visible_summaries, string.format("  ... and %d more", #commit_summaries - (max_display - 1)))
    return table.concat(visible_summaries, "\n")
  end
end

-- Helper function to create standard interactive command callbacks
-- Consolidates callback patterns from squash.lua, split.lua, commit.lua
M.create_interactive_callbacks = function(operation_name, display_id)
  return {
    on_success = function()
      vim.notify(string.format("Interactive %s completed", operation_name), vim.log.levels.INFO)
    end,
    on_error = function(exit_code)
      -- Error message already shown by interactive terminal
    end,
    on_cancel = function()
      vim.notify(string.format("Interactive %s cancelled", operation_name), vim.log.levels.INFO)
    end
  }
end

-- Helper function to standardize input prompting
-- Consolidates vim.ui.input patterns from commit.lua, split.lua, etc.
M.prompt_for_input = function(config)
  -- config: { prompt, default, validator, on_success, on_cancel, cancel_message }
  vim.ui.input({
    prompt = config.prompt,
    default = config.default or "",
  }, function(input)
    if not input or input:match("^%s*$") then
      local cancel_msg = config.cancel_message or "Operation cancelled"
      vim.notify(cancel_msg, vim.log.levels.INFO)
      if config.on_cancel then config.on_cancel() end
      return
    end

    if config.validator and not config.validator(input) then
      local error_msg = config.validation_error or "Invalid input"
      vim.notify(error_msg, vim.log.levels.ERROR)
      if config.on_cancel then config.on_cancel() end
      return
    end

    if config.on_success then config.on_success(input) end
  end)
end

-- Helper function to get target display name
-- Consolidates display name logic from squash.lua, split.lua, rebase.lua
M.get_target_display_name = function(target, target_type)
  if target_type == "commit" then
    return target.short_change_id or target.change_id:sub(1, 8)
  elseif target_type == "bookmark" then
    return "bookmark '" .. (target.display_name or target.name) .. "'"
  else
    return tostring(target)
  end
end

-- Helper function to build command arguments with common flags
-- Consolidates command building patterns from split.lua, squash.lua, rebase.lua
M.build_command_args = function(base_command, common_options, specific_options)
  local cmd_args = { base_command }

  -- Add common options
  if common_options then
    if common_options.interactive then
      table.insert(cmd_args, '--interactive')
    end

    if common_options.tool then
      table.insert(cmd_args, '--tool')
      table.insert(cmd_args, common_options.tool)
    end

    if common_options.message then
      table.insert(cmd_args, '--message')
      table.insert(cmd_args, common_options.message)
    end

    if common_options.revision then
      table.insert(cmd_args, '--revision')
      table.insert(cmd_args, common_options.revision)
    end

    if common_options.destination then
      table.insert(cmd_args, '--destination')
      table.insert(cmd_args, common_options.destination)
    end
  end

  -- Add specific options
  if specific_options then
    for _, arg in ipairs(specific_options) do
      table.insert(cmd_args, arg)
    end
  end

  return cmd_args
end

return M

