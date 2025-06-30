#!/usr/bin/env lua

-- Simple test script to verify bookmark parsing
local bookmark_commands = require('jj-nvim.jj.bookmark_commands')

print("Testing detailed bookmark parsing...")
local detailed_bookmarks = bookmark_commands.get_detailed_bookmarks()

print("Found " .. #detailed_bookmarks .. " bookmarks:")
for i, bookmark in ipairs(detailed_bookmarks) do
  print(string.format("%d: %s (type: %s, remote: %s, display: %s)", 
    i, 
    bookmark.name, 
    bookmark.type, 
    bookmark.remote_name or "none", 
    bookmark:get_display_name()))
end

print("\nTesting bookmark lookup for specific commit...")
local master_bookmarks = bookmark_commands.get_bookmarks_for_commit("4fea2b64")
print("Found " .. #master_bookmarks .. " bookmarks for commit 4fea2b64:")
for i, bookmark in ipairs(master_bookmarks) do
  print(string.format("%d: %s", i, bookmark:get_display_name()))
end