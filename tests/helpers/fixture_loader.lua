-- Fixture data loader for jj-nvim tests
-- Loads real jj output data captured from test repository
local M = {}

-- Get the plugin root directory
local function get_plugin_root()
  -- Get the directory where this file is located
  local current_file = debug.getinfo(1, "S").source:sub(2)
  local current_dir = vim.fn.fnamemodify(current_file, ':h')
  
  -- Go up to the plugin root (from tests/helpers to root)
  return vim.fn.fnamemodify(current_dir, ':h:h')
end

-- Path to fixture data directory
local FIXTURE_DIR = get_plugin_root() .. '/tests/fixtures/captured_data'

-- Load the real graph output (jj log with * separators)
function M.load_graph_output()
  local graph_file = FIXTURE_DIR .. '/graph_output.txt'
  local file = io.open(graph_file, 'r')
  if not file then
    error("Could not load graph output fixture: " .. graph_file)
  end
  
  local content = file:read('*all')
  file:close()
  
  return content
end

-- Load the real template output (jj log with structured template)
function M.load_template_output()
  local template_file = FIXTURE_DIR .. '/template_output.txt'
  local file = io.open(template_file, 'r')
  if not file then
    error("Could not load template output fixture: " .. template_file)
  end
  
  local content = file:read('*all')
  file:close()
  
  return content
end

-- Load both outputs as a pair (for mocking the dual-call pattern)
function M.load_jj_outputs()
  return {
    graph = M.load_graph_output(),
    template = M.load_template_output()
  }
end

-- Check if fixture files exist
function M.fixtures_available()
  local graph_file = FIXTURE_DIR .. '/graph_output.txt'
  local template_file = FIXTURE_DIR .. '/template_output.txt'
  
  local graph_exists = vim.fn.filereadable(graph_file) == 1
  local template_exists = vim.fn.filereadable(template_file) == 1
  
  return graph_exists and template_exists
end

-- Get path to test repository for live tests
function M.get_test_repo_path()
  return get_plugin_root() .. '/tests/fixtures/jj-log-testing'
end

-- Check if test repository is available
function M.test_repo_available()
  local repo_path = M.get_test_repo_path()
  local jj_dir = repo_path .. '/.jj'
  return vim.fn.isdirectory(jj_dir) == 1
end

-- Expose get_plugin_root for other modules
function M.get_plugin_root()
  return get_plugin_root()
end

return M