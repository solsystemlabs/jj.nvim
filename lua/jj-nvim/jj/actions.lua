local M = {}

local commands = require('jj-nvim.jj.commands')
local buffer = require('jj-nvim.ui.buffer')

-- Edit the specified commit
M.edit_commit = function(commit)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end

  -- Don't allow editing the root commit
  if commit.root then
    vim.notify("Cannot edit the root commit", vim.log.levels.WARN)
    return false
  end

  -- Use change_id for jj edit command
  local change_id = commit.change_id or commit.short_change_id
  if not change_id or change_id == "" then
    vim.notify("Invalid commit: missing change ID", vim.log.levels.ERROR)
    return false
  end

  vim.notify(string.format("Editing commit %s...", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)

  -- Execute jj edit command
  local result, err = commands.execute({'edit', change_id})
  
  if not result then
    vim.notify(string.format("Failed to edit commit: %s", err or "Unknown error"), vim.log.levels.ERROR)
    return false
  end

  -- Success feedback
  vim.notify(string.format("Now editing commit %s", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  
  return true
end

-- Get a user-friendly description of what the edit command will do
M.get_edit_description = function(commit)
  if not commit then
    return "No commit selected"
  end
  
  if commit.root then
    return "Cannot edit root commit"
  end
  
  local change_id = commit.short_change_id or commit.change_id:sub(1, 8)
  local description = commit:get_short_description()
  
  return string.format("Edit commit %s: %s", change_id, description)
end

-- Abandon the specified commit
M.abandon_commit = function(commit)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end

  -- Don't allow abandoning the root commit
  if commit.root then
    vim.notify("Cannot abandon the root commit", vim.log.levels.WARN)
    return false
  end

  -- Don't allow abandoning the current commit
  if commit:is_current() then
    vim.notify("Cannot abandon the current working copy commit", vim.log.levels.WARN)
    return false
  end

  local change_id = commit.change_id or commit.short_change_id
  if not change_id or change_id == "" then
    vim.notify("Invalid commit: missing change ID", vim.log.levels.ERROR)
    return false
  end

  -- Confirm before abandoning
  local description = commit:get_short_description()
  local confirm_msg = string.format("Abandon commit %s: %s? (y/N)", 
    commit.short_change_id or change_id:sub(1, 8), description)
  
  local choice = vim.fn.input(confirm_msg)
  if choice:lower() ~= 'y' and choice:lower() ~= 'yes' then
    vim.notify("Abandon cancelled", vim.log.levels.INFO)
    return false
  end

  vim.notify(string.format("Abandoning commit %s...", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)

  -- Execute jj abandon command
  local result, err = commands.execute({'abandon', change_id})
  
  if not result then
    vim.notify(string.format("Failed to abandon commit: %s", err or "Unknown error"), vim.log.levels.ERROR)
    return false
  end

  -- Success feedback
  vim.notify(string.format("Abandoned commit %s", commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  
  return true
end

-- Create a new child change from the specified parent commit
M.new_child = function(parent_commit, options)
  if not parent_commit then
    vim.notify("No parent commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}
  
  -- Validate parent commit data
  local change_id = parent_commit.change_id or parent_commit.short_change_id
  if not change_id or change_id == "" then
    vim.notify("Invalid parent commit: missing change ID", vim.log.levels.ERROR)
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
  local cmd_args = {'new'}
  
  -- Add parent specification
  table.insert(cmd_args, change_id)
  
  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  vim.notify(string.format("Creating new child of commit %s...", 
    parent_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)

  -- Execute jj new command with enhanced error handling
  local result, err = commands.execute(cmd_args)
  
  if not result then
    -- Enhanced error reporting
    local error_msg = err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot create child - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    end
    
    vim.notify(string.format("Failed to create new change: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Parse output for additional information
  local new_change_id = result:match("Working copy now at: (%w+)")
  if new_change_id then
    vim.notify(string.format("Created new change %s as child of %s", 
      new_change_id:sub(1, 8), parent_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new child change of %s", 
      parent_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  end
  
  return true
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

-- Create a new child change with a custom message
M.new_child_with_message = function(parent_commit, message)
  return M.new_child(parent_commit, { message = message })
end

-- Create a new change after the specified commit (sibling)
M.new_after = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}
  
  -- Validate target commit data
  local change_id = target_commit.change_id or target_commit.short_change_id
  if not change_id or change_id == "" then
    vim.notify("Invalid target commit: missing change ID", vim.log.levels.ERROR)
    return false
  end

  -- Build command arguments for jj new --after
  local cmd_args = {'new', '--after', change_id}
  
  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  vim.notify(string.format("Creating new change after commit %s...", 
    target_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)

  -- Execute jj new --after command
  local result, err = commands.execute(cmd_args)
  
  if not result then
    local error_msg = err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot create change - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    end
    
    vim.notify(string.format("Failed to create new change: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Parse output for additional information
  local new_change_id = result:match("Working copy now at: (%w+)")
  if new_change_id then
    vim.notify(string.format("Created new change %s after %s", 
      new_change_id:sub(1, 8), target_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new change after %s", 
      target_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  end
  
  return true
end

-- Create a new change before the specified commit (insert)
M.new_before = function(target_commit, options)
  if not target_commit then
    vim.notify("No target commit specified", vim.log.levels.WARN)
    return false
  end

  options = options or {}
  
  -- Validate target commit data
  local change_id = target_commit.change_id or target_commit.short_change_id
  if not change_id or change_id == "" then
    vim.notify("Invalid target commit: missing change ID", vim.log.levels.ERROR)
    return false
  end

  -- Don't allow inserting before root commit
  if target_commit.root then
    vim.notify("Cannot insert before the root commit", vim.log.levels.WARN)
    return false
  end

  -- Build command arguments for jj new --before
  local cmd_args = {'new', '--before', change_id}
  
  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  vim.notify(string.format("Creating new change before commit %s...", 
    target_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)

  -- Execute jj new --before command
  local result, err = commands.execute(cmd_args)
  
  if not result then
    local error_msg = err or "Unknown error"
    if error_msg:find("No such revision") then
      error_msg = "Commit not found - it may have been abandoned or modified"
    elseif error_msg:find("would create a cycle") then
      error_msg = "Cannot create change - would create a cycle in commit graph"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    end
    
    vim.notify(string.format("Failed to create new change: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Parse output for additional information
  local new_change_id = result:match("Working copy now at: (%w+)")
  if new_change_id then
    vim.notify(string.format("Created new change %s before %s", 
      new_change_id:sub(1, 8), target_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  else
    vim.notify(string.format("Created new change before %s", 
      target_commit.short_change_id or change_id:sub(1, 8)), vim.log.levels.INFO)
  end
  
  return true
end

return M