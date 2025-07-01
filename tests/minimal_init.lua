-- Minimal init for running tests
-- This file sets up the minimal environment needed for testing

local function setup_test_environment()
  -- Get the plugin directory (parent of tests directory)
  local test_dir = vim.fn.expand('<sfile>:p:h')
  local plugin_dir = vim.fn.fnamemodify(test_dir, ':h')
  
  -- Add the plugin to runtimepath
  vim.opt.runtimepath:prepend(plugin_dir)
  
  -- Ensure plenary is available
  local plenary_path = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
  if vim.fn.isdirectory(plenary_path) == 1 then
    vim.opt.runtimepath:prepend(plenary_path)
  end
  
  -- Set up some basic vim options needed for testing
  vim.opt.termguicolors = true
  vim.opt.background = 'dark'
  
  -- Disable some features that might interfere with testing
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1
end

setup_test_environment()