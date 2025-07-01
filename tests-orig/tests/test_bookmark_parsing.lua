#!/usr/bin/env lua

-- Test bookmark parsing with sample output
local sample_output = [[master: mttmrorw 4fea2b64 Fix diamond color in graph content
  @origin: mttmrorw 4fea2b64 Fix diamond color in graph content
real-work (deleted)
  @origin: lotmktrt 8e92528a revert wrapping code, though we might want to undo this since we still have work to do to get the graph working
test (deleted)
  @origin: skkzontn hidden 4b76baa5 (empty) test bookmark
test-delete: uqnmpyrt d97a04e9 Initial work to get bookmark management working
Hint: Bookmarks marked as deleted can be *deleted permanently* on the remote by running `jj git push --deleted`. Use `jj bookmark forget` if you don't want that.]]

-- Mock the bookmark module structures
local BOOKMARK_TYPES = {
  LOCAL = "local",
  REMOTE = "remote", 
  CONFLICTED = "conflicted"
}

local BOOKMARK_STATUS = {
  CLEAN = "clean",
  CONFLICTED = "conflicted",
  OUT_OF_SYNC = "out_of_sync"
}

local function new_bookmark(name, bookmark_type, target_commit, remote_name, status)
  return {
    name = name,
    type = bookmark_type or BOOKMARK_TYPES.LOCAL,
    target_commit = target_commit,
    remote_name = remote_name,
    status = status or BOOKMARK_STATUS.CLEAN,
    
    get_display_name = function(self)
      if self.type == BOOKMARK_TYPES.REMOTE then
        return string.format("%s@%s", self.name, self.remote_name or "origin")
      end
      return self.name
    end
  }
end

-- Parse bookmarks (simplified version)
local function parse_bookmarks(bookmark_output)
  local bookmarks = {}
  local lines = {}
  for line in bookmark_output:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  
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
        local remote_bookmark = new_bookmark(
          current_bookmark.name,
          BOOKMARK_TYPES.REMOTE,
          { id = commit_id, change_id = change_id, message = commit_msg or "" },
          remote_name
        )
        table.insert(bookmarks, remote_bookmark)
      end
      goto continue
    end
    
    -- Parse main bookmark line (local bookmark)  
    -- Format: name (status): change_id commit_id description
    local name, status_info, change_id, commit_id, commit_msg = line:match("^([^%s:]+)%s*(%([^)]*%)):%s*([%w%d]+)%s+([%w%d]+)%s+(.*)$")
    if not name then
      -- Try without status info
      name, change_id, commit_id, commit_msg = line:match("^([^%s:]+):%s*([%w%d]+)%s+([%w%d]+)%s+(.*)$")
      status_info = nil
    end
    
    if name and commit_id then
      local bookmark_type = BOOKMARK_TYPES.LOCAL
      local bookmark_status = BOOKMARK_STATUS.CLEAN
      
      -- Check if it's a deleted bookmark
      if status_info and status_info:match("deleted") then
        bookmark_status = BOOKMARK_STATUS.CONFLICTED
      end
      
      current_bookmark = new_bookmark(
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

-- Test the parsing
print("Testing bookmark parsing...")
local bookmarks = parse_bookmarks(sample_output)

print("Found " .. #bookmarks .. " bookmarks:")
for i, bookmark in ipairs(bookmarks) do
  print(string.format("%d: %s (type: %s, remote: %s, display: %s, commit: %s)", 
    i, 
    bookmark.name, 
    bookmark.type, 
    bookmark.remote_name or "none", 
    bookmark:get_display_name(),
    bookmark.target_commit and bookmark.target_commit.id or "none"))
end

-- Test commit lookup
print("\nTesting commit lookup for 4fea2b64...")
local commit_bookmarks = {}
for _, bookmark in ipairs(bookmarks) do
  if bookmark.target_commit and bookmark.target_commit.id then
    local target_id = bookmark.target_commit.id
    if target_id == "4fea2b64" or target_id:find("^" .. "4fea2b64") then
      table.insert(commit_bookmarks, bookmark)
    end
  end
end

print("Found " .. #commit_bookmarks .. " bookmarks for commit 4fea2b64:")
for i, bookmark in ipairs(commit_bookmarks) do
  print(string.format("%d: %s", i, bookmark:get_display_name()))
end