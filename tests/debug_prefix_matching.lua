#!/usr/bin/env lua

-- Test prefix matching issues
local bookmarks = {
    {name = "master", commit_id = "4fea2b64"},
    {name = "real-work", commit_id = "8e92528a"}, 
    {name = "test-delete", commit_id = "d97a04e9"}
}

local test_commits = {"02c2cdb9", "108c9b8e", "4fea2b64", "4f", "4fe", "4feb"}

print("Testing prefix matching issues...")

for _, test_commit in ipairs(test_commits) do
    print("\n--- Testing commit: " .. test_commit .. " ---")
    
    for _, bookmark in ipairs(bookmarks) do
        local target_id = bookmark.commit_id
        
        -- Test exact match
        if target_id == test_commit then
            print("  EXACT match: " .. bookmark.name)
        end
        
        -- Test prefix match (this is the current logic)
        if target_id:find("^" .. test_commit) then
            print("  PREFIX match: " .. bookmark.name .. " (target: " .. target_id .. ")")
        end
        
        -- Test if the test_commit is a prefix of target_id
        if test_commit:find("^" .. target_id) then
            print("  REVERSE PREFIX match: " .. bookmark.name .. " (target: " .. target_id .. ")")
        end
    end
end

print("\n=== Testing with actual commit IDs ===")
-- Test with real commit IDs that are showing the issue
local problematic_commits = {"02c2cdb9", "108c9b8e"}

for _, commit in ipairs(problematic_commits) do
    print("\nCommit " .. commit .. ":")
    for _, bookmark in ipairs(bookmarks) do
        if bookmark.commit_id:find("^" .. commit) then
            print("  Would match: " .. bookmark.name)
        end
    end
end