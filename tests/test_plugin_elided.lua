#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Quick test of plugin with elided sections
local jj_nvim = require('jj-nvim')

-- Initialize plugin
jj_nvim.setup({})

print("Plugin loaded successfully")
print("Elided sections should now render properly as separate lines")
print("You can test this by running: nvim -c 'lua require(\"jj-nvim\").show_log()'")