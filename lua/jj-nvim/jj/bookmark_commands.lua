local M = {}

local commands = require('jj-nvim.jj.commands')

-- Validate bookmark name
local function is_valid_bookmark_name(name)
  if not name or name == "" then
    return false, "Bookmark name cannot be empty"
  end

  if name:match("^%.") or name:match("%.$") then
    return false, "Bookmark name cannot start or end with '.'"
  end

  if name:match("%.%.") then
    return false, "Bookmark name cannot contain '..'"
  end

  if name:match("[%s@:]") then
    return false, "Bookmark name cannot contain spaces, '@', or ':'"
  end

  return true
end

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

  return result, nil
end


-- Get simple bookmark table with all bookmark info
M.get_all_bookmarks = function()
  -- Enhanced template to get comprehensive bookmark data
  local FIELD_SEP = "\x1F"
  local RECORD_SEP = "\x1E"
  local template = 'self.name() ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.remote(), self.remote(), "local") ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.present(), "present", "absent") ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.conflict(), "conflict", "clean") ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.present() && self.normal_target(), self.normal_target().commit_id().short(8), "no_commit") ++ "' ..
      FIELD_SEP .. '" ++ ' ..
      'if(self.tracked(), "tracked", "untracked") ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.tracking_present(), "tracking_present", "tracking_absent") ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.tracked(), self.tracking_ahead_count().lower(), "0") ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.tracked(), self.tracking_behind_count().lower(), "0") ++ "' .. FIELD_SEP .. '" ++ ' ..
      'if(self.present() && self.normal_target(), self.normal_target().change_id().short(8), "no_change_id") ++ "' ..
      RECORD_SEP .. '"'

  local cmd_args = { 'bookmark', 'list', '-a', '-T', template }

  local result, err = commands.execute(cmd_args)
  if not result then
    vim.notify("Failed to get bookmarks: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return {}
  end

  -- Parse into simple table
  local bookmarks = {}
  local bookmark_blocks = vim.split(result, RECORD_SEP, { plain = true })

  for _, bookmark_block in ipairs(bookmark_blocks) do
    local trimmed_block = bookmark_block:match("^%s*(.-)%s*$")

    if trimmed_block ~= "" and not trimmed_block:match("^Hint:") then
      local parts = vim.split(trimmed_block, FIELD_SEP, { plain = true })

      if #parts >= 10 then
        local bookmark = {
          name = parts[1] or "",
          remote = parts[2] ~= "local" and parts[2] or nil,
          present = parts[3] == "present",
          conflict = parts[4] == "conflict",
          commit_id = parts[5] ~= "no_commit" and parts[5] or nil,
          tracked = parts[6] == "tracked",
          tracking_present = parts[7] == "tracking_present",
          tracking_ahead_count = tonumber(parts[8]) or 0,
          tracking_behind_count = tonumber(parts[9]) or 0,
          change_id = parts[10] ~= "no_change_id" and parts[10] or nil
        }

        table.insert(bookmarks, bookmark)
      end
    end
  end

  -- Detect divergence between local and remote bookmarks
  local bookmark_names = {}
  for _, bookmark in ipairs(bookmarks) do
    if not bookmark_names[bookmark.name] then
      bookmark_names[bookmark.name] = {}
    end
    table.insert(bookmark_names[bookmark.name], bookmark)
  end
  
  -- Check for divergence and mark local bookmarks that differ from their remotes
  for name, name_bookmarks in pairs(bookmark_names) do
    local local_bookmark = nil
    local remote_bookmarks = {}
    
    -- Separate local and remote bookmarks
    for _, bookmark in ipairs(name_bookmarks) do
      if not bookmark.remote then
        local_bookmark = bookmark
      else
        table.insert(remote_bookmarks, bookmark)
      end
    end
    
    -- Check if local bookmark diverges from any remote with same name
    if local_bookmark and local_bookmark.commit_id then
      for _, remote_bookmark in ipairs(remote_bookmarks) do
        if remote_bookmark.commit_id and remote_bookmark.commit_id ~= local_bookmark.commit_id then
          local_bookmark.has_divergence = true
          break
        end
      end
    end
  end
  
  -- Update display names to include asterisk for divergent local bookmarks
  for _, bookmark in ipairs(bookmarks) do
    -- Generate base display name
    if bookmark.remote then
      bookmark.display_name = bookmark.name .. "@" .. bookmark.remote
    else
      bookmark.display_name = bookmark.name
      -- Add asterisk for divergent local bookmarks
      if bookmark.has_divergence then
        bookmark.display_name = bookmark.display_name .. "*"
      end
    end
    
    -- Add status indicators
    local status_parts = {}
    if not bookmark.present then
      table.insert(status_parts, "deleted")
    end
    if bookmark.conflict then
      table.insert(status_parts, "conflict")
    end
    
    if #status_parts > 0 then
      bookmark.display_name = bookmark.display_name .. " (" .. table.concat(status_parts, ", ") .. ")"
    end
  end

  return bookmarks
end

-- Create a new bookmark
M.create_bookmark = function(name, revision)
  local valid, err = is_valid_bookmark_name(name)
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
M.forget_bookmark = function(name, options)
  if not name or name == "" then
    vim.notify("Bookmark name required", vim.log.levels.ERROR)
    return false
  end

  options = options or {}
  
  local cmd_args = { 'bookmark', 'forget', name }

  -- Add --include-remotes flag if specified
  if options.include_remotes then
    table.insert(cmd_args, '--include-remotes')
  end

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

  local valid, err = is_valid_bookmark_name(new_name)
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
  local valid, err = is_valid_bookmark_name(name)
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
  local all_bookmarks = M.get_all_bookmarks()
  local commit_bookmarks = {}

  for _, bookmark in ipairs(all_bookmarks) do
    if bookmark.commit_id and bookmark.present then
      -- Match exact or prefix
      if bookmark.commit_id == commit_id or bookmark.commit_id:find("^" .. commit_id) then
        table.insert(commit_bookmarks, bookmark)
      end
    end
  end

  return commit_bookmarks
end

-- Push a bookmark with smart error handling and confirmations
M.push_bookmark = function(name, options)
  if not name or name == "" then
    vim.notify("Bookmark name required", vim.log.levels.ERROR)
    return false
  end

  options = options or {}
  
  local cmd_args = { 'git', 'push' }
  
  -- Add remote (default to origin)
  local remote = options.remote or 'origin'
  table.insert(cmd_args, remote)
  
  -- Add bookmark flag
  table.insert(cmd_args, '--bookmark')
  table.insert(cmd_args, name)
  
  -- Add optional flags
  if options.allow_new then
    table.insert(cmd_args, '--allow-new')
  end
  
  if options.deleted then
    table.insert(cmd_args, '--deleted')
  end
  
  if options.force then
    table.insert(cmd_args, '--force-with-lease')
  end
  
  if options.dry_run then
    table.insert(cmd_args, '--dry-run')
  end
  
  if options.allow_empty_description then
    table.insert(cmd_args, '--allow-empty-description')
  end
  
  if options.allow_private then
    table.insert(cmd_args, '--allow-private')
  end

  local result, exec_err = commands.execute(cmd_args)
  if not result then
    local error_msg = exec_err or "Unknown error"
    
    -- Smart confirmation for --allow-new flag
    local is_new_bookmark_error = error_msg:find("Refusing to create new remote bookmark") or 
                                 error_msg:find("allow%-new")
    
    if is_new_bookmark_error and not options.allow_new then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = string.format("Bookmark '%s' is new. Allow pushing new bookmark to remote?", name),
      }, function(choice)
        if choice == 'Yes' then
          -- Retry with --allow-new flag
          local retry_options = vim.tbl_extend("force", options, { allow_new = true })
          M.push_bookmark(name, retry_options)
        else
          vim.notify("Push cancelled", vim.log.levels.INFO)
        end
      end)
      return false -- Return false for the original attempt
    end
    
    -- Smart confirmation for empty description
    local is_empty_description_error = error_msg:find("empty descriptions") or 
                                      error_msg:find("no description")
    
    if is_empty_description_error and not options.allow_empty_description then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = string.format("Bookmark '%s' points to commits with empty descriptions. Allow pushing?", name),
      }, function(choice)
        if choice == 'Yes' then
          -- Retry with --allow-empty-description flag
          local retry_options = vim.tbl_extend("force", options, { allow_empty_description = true })
          M.push_bookmark(name, retry_options)
        else
          vim.notify("Push cancelled", vim.log.levels.INFO)
        end
      end)
      return false
    end
    
    -- Smart confirmation for private commits
    local is_private_commits_error = error_msg:find("private") and error_msg:find("commit")
    
    if is_private_commits_error and not options.allow_private then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = string.format("Bookmark '%s' points to private commits. Allow pushing?", name),
      }, function(choice)
        if choice == 'Yes' then
          -- Retry with --allow-private flag
          local retry_options = vim.tbl_extend("force", options, { allow_private = true })
          M.push_bookmark(name, retry_options)
        else
          vim.notify("Push cancelled", vim.log.levels.INFO)
        end
      end)
      return false
    end

    -- For other errors, show the error message
    vim.notify(string.format("Failed to push bookmark: %s", error_msg), vim.log.levels.ERROR)
    return false
  end

  -- Success notification
  local success_msg = "Pushed bookmark '%s' to %s"
  if options.dry_run then
    success_msg = "Push preview for bookmark '%s' to %s (dry run)"
  elseif options.deleted then
    success_msg = "Deleted bookmark '%s' on %s"
  elseif options.allow_new then
    success_msg = "Pushed new bookmark '%s' to %s"
  end
  
  vim.notify(string.format(success_msg, name, remote), vim.log.levels.INFO)

  -- Call success callback if provided
  if options.on_success then
    options.on_success()
  end

  return true
end


-- Filter bookmarks by criteria
local function filter_bookmarks(bookmarks, filter_fn)
  local filtered = {}
  for _, bookmark in ipairs(bookmarks) do
    if filter_fn(bookmark) then
      table.insert(filtered, bookmark)
    end
  end
  return filtered
end

-- Get local bookmarks for menus
M.get_local_bookmarks = function()
  local all_bookmarks = M.get_all_bookmarks()
  return filter_bookmarks(all_bookmarks, function(bookmark)
    return not bookmark.remote and bookmark.present
  end)
end

-- Get remote bookmarks for menus
M.get_remote_bookmarks = function()
  local all_bookmarks = M.get_all_bookmarks()
  return filter_bookmarks(all_bookmarks, function(bookmark)
    return bookmark.remote and bookmark.present
  end)
end

-- Get all present bookmarks for menus
M.get_all_present_bookmarks = function()
  local all_bookmarks = M.get_all_bookmarks()
  return filter_bookmarks(all_bookmarks, function(bookmark)
    return bookmark.present
  end)
end

return M
