local M = {}

local commands = require('jj-nvim.jj.commands')
local bookmark_core = require('jj-nvim.core.bookmark')

-- Cache for bookmark data
local bookmark_cache = {
  data = nil,
  last_update = 0,
  ttl = 5000 -- 5 seconds TTL
}

-- Helper function to execute bookmark commands with error handling
local function execute_bookmark_command(cmd_args, error_context)
  local result, err = commands.execute(cmd_args)
  
  if not result then
    local error_msg = err or "Unknown error"
    local is_backwards_move = error_context == "move bookmark" and 
      (error_msg:find("would move backwards") or error_msg:find("backwards") or error_msg:find("ancestor"))
    
    if error_msg:find("No such bookmark") then
      error_msg = "Bookmark not found"
    elseif error_msg:find("already exists") then
      error_msg = "Bookmark already exists"
    elseif error_msg:find("not in workspace") then
      error_msg = "Not in a jj workspace"
    elseif error_msg:find("Invalid bookmark name") then
      error_msg = "Invalid bookmark name"
    end
    
    -- Don't show generic error for backwards moves - let move_bookmark handle it with confirmation dialog
    if not is_backwards_move then
      vim.notify(string.format("Failed to %s: %s", error_context, error_msg), vim.log.levels.ERROR)
    end
    return false, err -- Return original error for move_bookmark to analyze
  end
  
  -- Clear cache on successful modification
  bookmark_cache.data = nil
  return result, nil
end

-- Get all bookmarks with caching
M.get_bookmarks = function(options)
  options = options or {}
  
  -- Check cache
  local now = vim.loop.now()
  if bookmark_cache.data and (now - bookmark_cache.last_update) < bookmark_cache.ttl then
    return bookmark_cache.data
  end
  
  -- Build command arguments
  local cmd_args = { 'bookmark', 'list' }
  
  if options.all_remotes then
    table.insert(cmd_args, '--all-remotes')
  end
  
  if options.remote then
    table.insert(cmd_args, '--remote')
    table.insert(cmd_args, options.remote)
  end
  
  if options.tracked then
    table.insert(cmd_args, '--tracked')
  end
  
  if options.conflicted then
    table.insert(cmd_args, '--conflicted')
  end
  
  if options.revisions then
    table.insert(cmd_args, '--revisions')
    table.insert(cmd_args, options.revisions)
  end
  
  local result, err = commands.execute(cmd_args)
  if not result then
    vim.notify("Failed to get bookmarks: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return {}
  end
  
  local bookmarks = bookmark_core.parse_bookmarks(result)
  
  -- Cache the result
  bookmark_cache.data = bookmarks
  bookmark_cache.last_update = now
  
  return bookmarks
end

-- Create a new bookmark
M.create_bookmark = function(name, revision)
  local valid, err = bookmark_core.is_valid_bookmark_name(name)
  if not valid then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end
  
  local cmd_args = { 'bookmark', 'create', name }
  
  if revision then
    table.insert(cmd_args, '--revision')
    table.insert(cmd_args, revision)
  end
  
  local result, exec_err = execute_bookmark_command(cmd_args, "create bookmark")
  if not result then
    return false
  end
  
  return true
end

-- Delete a bookmark
M.delete_bookmark = function(name)
  if not name or name == "" then
    vim.notify("Bookmark name required", vim.log.levels.ERROR)
    return false
  end
  
  local cmd_args = { 'bookmark', 'delete', name }
  
  local result, exec_err = execute_bookmark_command(cmd_args, "delete bookmark")
  if not result then
    return false
  end
  
  return true
end

-- Forget a bookmark (without propagating deletion)
M.forget_bookmark = function(name)
  if not name or name == "" then
    vim.notify("Bookmark name required", vim.log.levels.ERROR)
    return false
  end
  
  local cmd_args = { 'bookmark', 'forget', name }
  
  local result, exec_err = execute_bookmark_command(cmd_args, "forget bookmark")
  if not result then
    return false
  end
  
  return true
end

-- Move bookmark to target revision
M.move_bookmark = function(name, target_revision, options)
  if not name or name == "" then
    vim.notify("Bookmark name required", vim.log.levels.ERROR)
    return false
  end
  
  if not target_revision or target_revision == "" then
    vim.notify("Target revision required", vim.log.levels.ERROR)
    return false
  end
  
  options = options or {}
  
  local cmd_args = { 'bookmark', 'move', name, '--to', target_revision }
  
  if options.allow_backwards then
    table.insert(cmd_args, '--allow-backwards')
  end
  
  local result, exec_err = execute_bookmark_command(cmd_args, "move bookmark")
  if not result then
    -- Check if this is a backwards move error and offer to retry
    if exec_err and (exec_err:find("would move backwards") or exec_err:find("backwards") or exec_err:find("ancestor")) then
      if not options.allow_backwards then
        -- Show confirmation dialog for backwards move
        vim.ui.select({ 'Yes', 'No' }, {
          prompt = string.format("Bookmark '%s' would move backwards to an ancestor commit. Allow backwards move?", name),
        }, function(choice)
          if choice == 'Yes' then
            -- Retry with --allow-backwards flag
            local retry_options = vim.tbl_extend("force", options, { allow_backwards = true })
            M.move_bookmark(name, target_revision, retry_options)
          else
            vim.notify("Move bookmark cancelled", vim.log.levels.INFO)
          end
        end)
        return false -- Return false for the original attempt
      end
    end
    -- For other errors, execute_bookmark_command already showed the error message
    return false
  end
  
  -- Success notification
  vim.notify(string.format("Moved bookmark '%s' to %s", name, target_revision:sub(1, 8)), vim.log.levels.INFO)
  
  -- Call success callback if provided
  if options.on_success then
    options.on_success()
  end
  
  return true
end

-- Rename a bookmark
M.rename_bookmark = function(old_name, new_name)
  if not old_name or old_name == "" then
    vim.notify("Old bookmark name required", vim.log.levels.ERROR)
    return false
  end
  
  local valid, err = bookmark_core.is_valid_bookmark_name(new_name)
  if not valid then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end
  
  local cmd_args = { 'bookmark', 'rename', old_name, new_name }
  
  local result, exec_err = execute_bookmark_command(cmd_args, "rename bookmark")
  if not result then
    return false
  end
  
  return true
end

-- Set bookmark to point to a commit
M.set_bookmark = function(name, revision)
  local valid, err = bookmark_core.is_valid_bookmark_name(name)
  if not valid then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end
  
  local cmd_args = { 'bookmark', 'set', name }
  
  if revision then
    table.insert(cmd_args, '--revision')
    table.insert(cmd_args, revision)
  end
  
  local result, exec_err = execute_bookmark_command(cmd_args, "set bookmark")
  if not result then
    return false
  end
  
  return true
end

-- Track a remote bookmark
M.track_bookmark = function(bookmark_name, remote_name)
  if not bookmark_name or bookmark_name == "" then
    vim.notify("Bookmark name required", vim.log.levels.ERROR)
    return false
  end
  
  local bookmark_ref = bookmark_name
  if remote_name then
    bookmark_ref = string.format("%s@%s", bookmark_name, remote_name)
  end
  
  local cmd_args = { 'bookmark', 'track', bookmark_ref }
  
  local result, exec_err = execute_bookmark_command(cmd_args, "track bookmark")
  if not result then
    return false
  end
  
  return true
end

-- Untrack a remote bookmark
M.untrack_bookmark = function(bookmark_name, remote_name)
  if not bookmark_name or bookmark_name == "" then
    vim.notify("Bookmark name required", vim.log.levels.ERROR)
    return false
  end
  
  local bookmark_ref = bookmark_name
  if remote_name then
    bookmark_ref = string.format("%s@%s", bookmark_name, remote_name)
  end
  
  local cmd_args = { 'bookmark', 'untrack', bookmark_ref }
  
  local result, exec_err = execute_bookmark_command(cmd_args, "untrack bookmark")
  if not result then
    return false
  end
  
  return true
end

-- Get bookmarks for a specific commit
M.get_bookmarks_for_commit = function(commit_id)
  local bookmarks = M.get_bookmarks({ all_remotes = true })
  return bookmark_core.get_bookmarks_for_commit(bookmarks, commit_id)
end

-- Clear the bookmark cache (useful for refresh operations)
M.clear_cache = function()
  bookmark_cache.data = nil
end

-- Get filtered bookmarks
M.get_filtered_bookmarks = function(filters)
  local bookmarks = M.get_bookmarks({ all_remotes = true })
  return bookmark_core.filter_bookmarks(bookmarks, filters)
end

-- Get bookmark groups (local + remote variants grouped by name)
M.get_bookmark_groups = function()
  local bookmarks = M.get_bookmarks({ all_remotes = true })
  return bookmark_core.group_bookmarks_by_name(bookmarks)
end

return M