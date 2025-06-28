#!/usr/bin/env nvim

-- Add lua directory to package path
vim.opt.runtimepath:prepend('.')

-- Simple test to show the log with colors
local jj_nvim = require('jj-nvim')

-- Setup the plugin
jj_nvim.setup({})

-- Show the log
jj_nvim.show_log()

-- Print success message
print("JJ log opened! Check if colors match jj command line output.")
print("You can compare with: jj log --limit 10")