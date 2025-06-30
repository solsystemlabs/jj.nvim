local M = {}

-- Bookmark types
M.BOOKMARK_TYPES = {
  LOCAL = "local",
  REMOTE = "remote",
  CONFLICTED = "conflicted"
}

-- Bookmark status
M.BOOKMARK_STATUS = {
  CLEAN = "clean",
  CONFLICTED = "conflicted",
  OUT_OF_SYNC = "out_of_sync"
}

-- Create a new bookmark object
M.new_bookmark = function(name, bookmark_type, target_commit, remote_name, status)
  return {
    name = name,
    type = bookmark_type or M.BOOKMARK_TYPES.LOCAL,
    target_commit = target_commit,
    remote_name = remote_name,
    status = status or M.BOOKMARK_STATUS.CLEAN,
    
    -- Methods
    is_local = function(self)
      return self.type == M.BOOKMARK_TYPES.LOCAL or self.type == M.BOOKMARK_TYPES.CONFLICTED
    end,
    
    is_remote = function(self)
      return self.type == M.BOOKMARK_TYPES.REMOTE or self.type == M.BOOKMARK_TYPES.CONFLICTED
    end,
    
    is_conflicted = function(self)
      return self.type == M.BOOKMARK_TYPES.CONFLICTED or self.status == M.BOOKMARK_STATUS.CONFLICTED
    end,
    
    get_display_name = function(self)
      local base_name = self.name
      if self.type == M.BOOKMARK_TYPES.REMOTE then
        base_name = string.format("%s@%s", self.name, self.remote_name or "origin")
      end
      
      -- Add status indicators
      local status_indicators = {}
      
      -- Add presence indicator (for absent/deleted bookmarks)
      if self.present == false then
        table.insert(status_indicators, "deleted")
      end
      
      -- Add conflict indicator
      if self:is_conflicted() then
        table.insert(status_indicators, "conflict")
      end
      
      -- Add tracking indicator for remote bookmarks
      if self.type == M.BOOKMARK_TYPES.REMOTE and self.tracking_status == "untracked" then
        table.insert(status_indicators, "untracked")
      end
      
      -- Combine base name with status indicators
      if #status_indicators > 0 then
        return string.format("%s (%s)", base_name, table.concat(status_indicators, ", "))
      end
      
      return base_name
    end,
    
    get_full_identifier = function(self)
      if self.type == M.BOOKMARK_TYPES.REMOTE then
        return string.format("%s@%s", self.name, self.remote_name or "origin")
      end
      return self.name
    end
  }
end

-- Parse bookmark list output from jj
M.parse_bookmarks = function(bookmark_output)
  if not bookmark_output or bookmark_output == "" then
    return {}
  end
  
  local bookmarks = {}
  local lines = vim.split(bookmark_output, '\n', { plain = true })
  
  local current_bookmark = nil
  
  for _, line in ipairs(lines) do
    -- Skip empty lines and hint lines
    if line:match("^%s*$") or line:match("^Hint:") then
      goto continue
    end
    
    -- Check if this is a remote bookmark line (starts with whitespace and @)
    local remote_line = line:match("^%s+@(.+)$")
    if remote_line and current_bookmark then
      -- Parse remote bookmark: @origin: change_id commit_id commit_message
      local remote_name, change_id, commit_id, commit_msg = remote_line:match("^([^:]+):%s*([%w%d]+)%s+([%w%d]+)%s+(.*)$")
      if remote_name and commit_id then
        -- Create remote bookmark
        local remote_bookmark = M.new_bookmark(
          current_bookmark.name,
          M.BOOKMARK_TYPES.REMOTE,
          { id = commit_id, change_id = change_id, message = commit_msg or "" },
          remote_name
        )
        
        -- Check if local and remote targets differ (conflict or out of sync)
        if current_bookmark.target_commit.id ~= commit_id then
          current_bookmark.status = M.BOOKMARK_STATUS.CONFLICTED
          current_bookmark.type = M.BOOKMARK_TYPES.CONFLICTED
          remote_bookmark.status = M.BOOKMARK_STATUS.CONFLICTED
        end
        
        table.insert(bookmarks, remote_bookmark)
      end
      goto continue
    end
    
    -- Parse main bookmark line (local bookmark)
    -- Handle both normal bookmarks and deleted bookmarks
    -- Format: name (status): change_id commit_id description
    local name, status_info, change_id, commit_id, commit_msg = line:match("^([^%s:]+)%s*(%([^)]*%)):%s*([%w%d]+)%s+([%w%d]+)%s+(.*)$")
    if not name then
      -- Try without status info  
      name, change_id, commit_id, commit_msg = line:match("^([^%s:]+):%s*([%w%d]+)%s+([%w%d]+)%s+(.*)$")
      status_info = nil
    end
    
    if name and commit_id then
      local bookmark_type = M.BOOKMARK_TYPES.LOCAL
      local bookmark_status = M.BOOKMARK_STATUS.CLEAN
      
      -- Check if it's a deleted bookmark
      if status_info and status_info:match("deleted") then
        bookmark_status = M.BOOKMARK_STATUS.CONFLICTED
      end
      
      current_bookmark = M.new_bookmark(
        name,
        bookmark_type,
        { id = commit_id, change_id = change_id, message = commit_msg or "" },
        nil,
        bookmark_status
      )
      table.insert(bookmarks, current_bookmark)
    end
    
    ::continue::
  end
  
  return bookmarks
end

-- Filter bookmarks by type
M.filter_bookmarks = function(bookmarks, filters)
  if not filters then
    return bookmarks
  end
  
  local filtered = {}
  
  for _, bookmark in ipairs(bookmarks) do
    local include = true
    
    if filters.local_only and not bookmark:is_local() then
      include = false
    end
    
    if filters.remote_only and not bookmark:is_remote() then
      include = false
    end
    
    if filters.conflicted_only and not bookmark:is_conflicted() then
      include = false
    end
    
    if filters.name_pattern and not bookmark.name:match(filters.name_pattern) then
      include = false
    end
    
    if include then
      table.insert(filtered, bookmark)
    end
  end
  
  return filtered
end

-- Get bookmarks for a specific commit
M.get_bookmarks_for_commit = function(bookmarks, commit_id)
  local commit_bookmarks = {}
  
  if not commit_id or commit_id == "" then
    return commit_bookmarks
  end
  
  for _, bookmark in ipairs(bookmarks) do
    if bookmark.target_commit and bookmark.target_commit.id then
      local target_id = bookmark.target_commit.id
      -- Match if the target starts with the commit_id (prefix match for short IDs)
      if target_id == commit_id or target_id:find("^" .. commit_id) then
        table.insert(commit_bookmarks, bookmark)
      end
    end
  end
  
  return commit_bookmarks
end

-- Group bookmarks by name (local + remote variants)
M.group_bookmarks_by_name = function(bookmarks)
  local groups = {}
  
  for _, bookmark in ipairs(bookmarks) do
    if not groups[bookmark.name] then
      groups[bookmark.name] = {}
    end
    table.insert(groups[bookmark.name], bookmark)
  end
  
  return groups
end

-- Sort bookmarks by name, with local bookmarks first
M.sort_bookmarks = function(bookmarks)
  table.sort(bookmarks, function(a, b)
    if a.name ~= b.name then
      return a.name < b.name
    end
    -- Same name: local before remote
    if a.type ~= b.type then
      if a.type == M.BOOKMARK_TYPES.LOCAL then
        return true
      elseif b.type == M.BOOKMARK_TYPES.LOCAL then
        return false
      end
    end
    return false
  end)
  
  return bookmarks
end

-- Validate bookmark name
M.is_valid_bookmark_name = function(name)
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

return M