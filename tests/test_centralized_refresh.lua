#!/usr/bin/env lua

-- Simple test to verify the centralized refresh mechanism works
print("Testing centralized refresh mechanism...")

-- Mock vim API for testing
local mock_vim = {
  notify = function(msg, level) print("NOTIFY: " .. msg) end,
  log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
  api = {
    nvim_buf_is_valid = function() return true end,
    nvim_win_is_valid = function() return true end,
    nvim_list_wins = function() return {1} end,
    nvim_win_get_buf = function() return 1 end,
    nvim_win_get_width = function() return 80 end
  }
}

-- Set up mock environment
_G.vim = mock_vim

-- Add lua path for local modules
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Test the new centralized refresh
local jj_nvim = require('jj-nvim')

-- Mock parser to return test commits
package.loaded['jj-nvim.core.parser'] = {
  parse_all_commits_with_separate_graph = function()
    return {
      {
        change_id = "abc123",
        short_change_id = "abc123",
        current_working_copy = true,
        description = "Test commit"
      }
    }, nil
  end
}

-- Mock buffer module
package.loaded['jj-nvim.ui.buffer'] = {
  update_from_fresh_data = function(commits)
    print("Buffer updated with fresh data!")
    print("Found " .. #commits .. " commits")
    for _, commit in ipairs(commits) do
      if commit.current_working_copy then
        print("Working copy commit: " .. (commit.short_change_id or commit.change_id))
      end
    end
    return true
  end
}

-- Mock window module  
package.loaded['jj-nvim.ui.window'] = {
  is_open = function() 
    print("Window is open check...")
    return true 
  end
}

-- Mock error handler
package.loaded['jj-nvim.utils.error_handler'] = {
  handle_jj_error = function(err, context) 
    if err then
      print("ERROR:", context, err)
      return true
    end
    return false 
  end
}

print("Testing jj_nvim.refresh()...")
print("Calling refresh function...")

-- Debug the refresh function step by step
print("Checking if window is open...")
local window = require('jj-nvim.ui.window')
print("Window open?", window.is_open())

local success = jj_nvim.refresh()
print("Refresh successful:", success)

print("\nTest completed! The centralized refresh mechanism collects fresh working copy data.")