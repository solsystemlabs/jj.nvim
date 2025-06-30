#!/usr/bin/env lua

-- Debug what's happening with bookmark matching
print("=== Debugging Bookmark Issue ===")

-- Simulate the template output we know we're getting
local template_result = "master\x1flocal\x1fpresent\x1fclean\x1funtracked\x1f4fea2b64\x1emaster\x1forigin\x1fpresent\x1fclean\x1ftracked\x1f4fea2b64\x1ereal-work\x1flocal\x1fabsent\x1fclean\x1funtracked\x1fno_commit\x1ereal-work\x1forigin\x1fpresent\x1fclean\x1ftracked\x1f8e92528a\x1etest\x1flocal\x1fabsent\x1fclean\x1funtracked\x1fno_commit\x1etest\x1forigin\x1fpresent\x1fclean\x1ftracked\x1f4b76baa5\x1etest-delete\x1flocal\x1fpresent\x1fclean\x1funtracked\x1fd97a04e9\x1e"

local FIELD_SEP = "\x1F"
local RECORD_SEP = "\x1E"

print("Template result length: " .. #template_result)
print("First 100 chars: " .. template_result:sub(1, 100):gsub("[\x1F\x1E]", "|"))

-- Parse the bookmarks
local bookmarks = {}
local bookmark_blocks = {}
for block in template_result:gmatch("[^" .. RECORD_SEP .. "]+") do
    if block ~= "" then
        table.insert(bookmark_blocks, block)
    end
end

print("\nFound " .. #bookmark_blocks .. " bookmark blocks")

for i, block in ipairs(bookmark_blocks) do
    local parts = {}
    for part in block:gmatch("[^" .. FIELD_SEP .. "]+") do
        table.insert(parts, part)
    end
    
    if #parts >= 6 then
        local name = parts[1]
        local remote_type = parts[2] 
        local presence = parts[3]
        local commit_id = parts[6]
        
        print(string.format("Block %d: name='%s', type='%s', present='%s', commit='%s'", 
            i, name, remote_type, presence, commit_id))
        
        -- Store bookmark info
        table.insert(bookmarks, {
            name = name,
            type = remote_type == "local" and "local" or "remote",
            present = presence == "present",
            commit_id = commit_id ~= "no_commit" and commit_id or nil
        })
    else
        print("Block " .. i .. " has insufficient parts: " .. #parts)
    end
end

-- Test commit matching
local test_commits = {"e5b010e1", "108c9b8e", "4fea2b64", "8e92528a", "d97a04e9"}

for _, commit_id in ipairs(test_commits) do
    print("\n--- Testing commit: " .. commit_id .. " ---")
    local matching_bookmarks = {}
    
    for _, bookmark in ipairs(bookmarks) do
        if bookmark.commit_id then
            -- Test exact match
            if bookmark.commit_id == commit_id then
                table.insert(matching_bookmarks, bookmark)
                print("  EXACT match: " .. bookmark.name .. " (" .. bookmark.type .. ")")
            -- Test prefix match  
            elseif bookmark.commit_id:find("^" .. commit_id) then
                table.insert(matching_bookmarks, bookmark)
                print("  PREFIX match: " .. bookmark.name .. " (" .. bookmark.type .. ")")
            end
        end
    end
    
    if #matching_bookmarks == 0 then
        print("  No matching bookmarks")
    else
        print("  Total matches: " .. #matching_bookmarks)
    end
end