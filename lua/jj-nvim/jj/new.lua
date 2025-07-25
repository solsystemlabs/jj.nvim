local M = {}

local command_utils = require('jj-nvim.jj.command_utils')
local commands = require('jj-nvim.jj.commands')

-- Import helper functions from command_utils
local get_change_id = command_utils.get_change_id
local get_short_display_id = command_utils.get_short_display_id
local execute_with_error_handling = command_utils.execute_with_error_handling

-- Helper function to get the current working copy change ID
local function get_current_working_copy_id()
  local result, err = commands.execute({ 'log', '--template', 'change_id', '--no-graph', '-r', '@', '--limit', '1' }, { silent = true })
  if result and result ~= "" then
    -- Trim whitespace and return the change ID
    return result:gsub("^%s*(.-)%s*$", "%1")
  end
  return nil
end

-- Create a new child change from the specified parent commit
M.new_child = function(parent_commit, options)
  if not parent_commit then
    vim.notify("No parent commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  local change_id, err = get_change_id(parent_commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Special handling for root commit - jj actually allows this but warn user
  if parent_commit.root then
    local confirm_msg = "Create child of root commit? This will create a new branch. (y/N)"
    local choice = vim.fn.input(confirm_msg)
    if choice:lower() ~= 'y' and choice:lower() ~= 'yes' then
      vim.notify("New change cancelled", vim.log.levels.INFO)
      return false
    end
  end

  -- Build command arguments
  local cmd_args = { 'new', change_id }

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local display_id = get_short_display_id(parent_commit, change_id)
  vim.notify(string.format("Creating new child of commit %s...", display_id), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  -- Get the current working copy change ID (which is the newly created change)
  local new_change_id = get_current_working_copy_id()
  
  if new_change_id then
    vim.notify(string.format("Created new change %s as child of %s",
      new_change_id:sub(1, 8), display_id), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new child change of %s", display_id), vim.log.levels.INFO)
  end

  return true, new_change_id
end

-- Get a user-friendly description of what the new child command will do
M.get_new_child_description = function(parent_commit)
  if not parent_commit then
    return "No parent commit selected"
  end

  local change_id = parent_commit.short_change_id or parent_commit.change_id:sub(1, 8)
  local description = parent_commit:get_short_description()

  if parent_commit.root then
    return string.format("Create new branch from root %s: %s", change_id, description)
  end

  return string.format("Create new child of %s: %s", change_id, description)
end

-- Create a new change after the specified commit (sibling)
M.new_after = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  local change_id, err = get_change_id(target_commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Build command arguments for jj new --after
  local cmd_args = { 'new', '--after', change_id }

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local display_id = get_short_display_id(target_commit, change_id)
  vim.notify(string.format("Creating new change after commit %s...", display_id), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  -- Get the current working copy change ID (which is the newly created change)
  local new_change_id = get_current_working_copy_id()
  
  if new_change_id then
    vim.notify(string.format("Created new change %s after %s",
      new_change_id:sub(1, 8), display_id), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new change after %s", display_id), vim.log.levels.INFO)
  end

  return true, new_change_id
end

-- Create a new change before the specified commit (insert)
M.new_before = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  local change_id, err = get_change_id(target_commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Don't allow inserting before root commit
  if target_commit.root then
    vim.notify("Cannot insert before the root commit", vim.log.levels.WARN)
    return false
  end

  -- Build command arguments for jj new --before
  local cmd_args = { 'new', '--before', change_id }

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local display_id = get_short_display_id(target_commit, change_id)
  vim.notify(string.format("Creating new change before commit %s...", display_id), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  -- Get the current working copy change ID (which is the newly created change)
  local new_change_id = get_current_working_copy_id()
  
  if new_change_id then
    vim.notify(string.format("Created new change %s before %s",
      new_change_id:sub(1, 8), display_id), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new change before %s", display_id), vim.log.levels.INFO)
  end

  return true, new_change_id
end

-- Create a new change with multiple parents using change IDs directly
M.new_with_change_ids = function(change_ids, options)
  if not change_ids or type(change_ids) ~= 'table' or #change_ids == 0 then
    vim.notify("No change IDs specified", vim.log.levels.WARN)
    return false
  end

  if #change_ids < 2 then
    vim.notify("At least 2 change IDs required for multi-parent change", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Build command arguments for jj new with multiple change IDs
  local cmd_args = { 'new' }

  -- Add all change IDs directly
  for _, change_id in ipairs(change_ids) do
    table.insert(cmd_args, change_id)
  end

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  local changes_str = table.concat(change_ids, ", ")
  vim.notify(string.format("Creating merge commit with parents: %s...", changes_str), vim.log.levels.INFO)

  local result, exec_err = execute_with_error_handling(cmd_args, "create merge commit")
  if not result then
    return false
  end

  -- Get the current working copy change ID (which is the newly created change)
  local new_change_id = get_current_working_copy_id()
  
  if new_change_id then
    vim.notify(string.format("Created merge commit %s with parents: %s",
      new_change_id:sub(1, 8), changes_str), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created merge commit with parents: %s", changes_str), vim.log.levels.INFO)
  end

  return true, new_change_id
end

-- Create a simple new change (jj new)
M.new_simple = function(options)
  options = options or {}

  -- Build command arguments
  local cmd_args = { 'new' }

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, "-m")
    table.insert(cmd_args, options.message)
  end

  local result, exec_err = execute_with_error_handling(cmd_args, "create new change")
  if not result then
    return false
  end

  -- Get the current working copy change ID (which is the newly created change)
  local new_change_id = get_current_working_copy_id()
  
  return true, new_change_id
end

return M