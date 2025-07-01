#!/usr/bin/env lua

-- Main test runner using plenary.nvim
-- Usage: 
--   From Neovim: :lua require('tests.run_tests')
--   From command line: nvim --headless -c "lua require('tests.run_tests')" -c "quit"

local function run_tests()
  -- Check if plenary is available
  local has_plenary, plenary = pcall(require, 'plenary.test_harness')
  
  if not has_plenary then
    local error_msg = [[
plenary.nvim is required to run tests. Please install it first:

Using lazy.nvim:
  { 'nvim-lua/plenary.nvim' }

Using packer.nvim:
  use 'nvim-lua/plenary.nvim'

Using vim-plug:
  Plug 'nvim-lua/plenary.nvim'
]]
    if vim and vim.notify then
      vim.notify(error_msg, vim.log.levels.ERROR)
    else
      print(error_msg)
    end
    return false
  end

  -- Set up test environment
  local test_dir = vim.fn.expand('%:p:h')
  local plugin_root = vim.fn.fnamemodify(test_dir, ':h')
  
  -- Add plugin to runtime path if not already there
  local rtp = vim.o.runtimepath
  if not string.find(rtp, plugin_root, 1, true) then
    vim.opt.runtimepath:prepend(plugin_root)
  end

  print("=== JJ-NVIM TEST SUITE ===")
  print("Plugin root: " .. plugin_root)
  print("Running tests with plenary.nvim...\n")

  -- Run all tests in the spec directory
  local spec_dir = test_dir .. '/spec'
  
  plenary.test_directory(spec_dir, {
    minimal_init = test_dir .. '/minimal_init.lua',
    sequential = false, -- Run tests in parallel where possible
  })
end

-- Auto-run if called directly
if not pcall(debug.getlocal, 4, 1) then
  run_tests()
end

return { run = run_tests }