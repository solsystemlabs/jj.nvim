-- Test data generation utility for jj-nvim
-- Regenerates fixture data from the test repository
local M = {}

local fixture_loader = require('tests.helpers.fixture_loader')

-- Get the template string used by the parser
local function get_commit_template()
  -- This should match the COMMIT_TEMPLATE from the parser
  return 'change_id ++ "\\x1F" ++ commit_id ++ "\\x1F" ++ change_id.short(8) ++ "\\x1F" ++ commit_id.short(8) ++ "\\x1F" ++ change_id.shortest() ++ "\\x1F" ++ commit_id.shortest() ++ "\\x1F" ++ author.name() ++ "\\x1F" ++ author.email() ++ "\\x1F" ++ author.timestamp() ++ "\\x1F" ++ description.first_line() ++ "\\x1F" ++ description ++ "\\x1F" ++ if(current_working_copy, "true", "false") ++ "\\x1F" ++ if(empty, "true", "false") ++ "\\x1F" ++ if(mine, "true", "false") ++ "\\x1F" ++ if(root, "true", "false") ++ "\\x1F" ++ if(conflict, "true", "false") ++ "\\x1F" ++ bookmarks.join(",") ++ "\\x1F" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\\x1E\\n"'
end

-- Regenerate fixture data from the test repository
function M.regenerate_fixtures()
  if not fixture_loader.test_repo_available() then
    error("Test repository not available at: " .. fixture_loader.get_test_repo_path())
  end
  
  local repo_path = fixture_loader.get_test_repo_path()
  local fixture_dir = fixture_loader.get_plugin_root() .. '/tests/fixtures/captured_data'
  
  -- Ensure fixture directory exists
  vim.fn.mkdir(fixture_dir, 'p')
  
  -- Generate graph output
  local graph_cmd = string.format('cd "%s" && jj log --template \'"*" ++ commit_id.short(8)\'', repo_path)
  local graph_result = vim.fn.system(graph_cmd)
  
  if vim.v.shell_error ~= 0 then
    error("Failed to generate graph output: " .. graph_result)
  end
  
  -- Write graph output
  local graph_file = fixture_dir .. '/graph_output.txt'
  local graph_handle = io.open(graph_file, 'w')
  if not graph_handle then
    error("Could not open graph output file for writing: " .. graph_file)
  end
  graph_handle:write(graph_result)
  graph_handle:close()
  
  -- Generate template output
  local template_cmd = string.format('cd "%s" && jj log --template \'%s\' --no-graph', repo_path, get_commit_template())
  local template_result = vim.fn.system(template_cmd)
  
  if vim.v.shell_error ~= 0 then
    error("Failed to generate template output: " .. template_result)
  end
  
  -- Write template output
  local template_file = fixture_dir .. '/template_output.txt'
  local template_handle = io.open(template_file, 'w')
  if not template_handle then
    error("Could not open template output file for writing: " .. template_file)
  end
  template_handle:write(template_result)
  template_handle:close()
  
  print("Fixture data regenerated:")
  print("  Graph: " .. graph_file)
  print("  Template: " .. template_file)
  
  return true
end

-- Generate fixture data with different options
function M.generate_fixtures_with_options(options)
  options = options or {}
  
  if not fixture_loader.test_repo_available() then
    error("Test repository not available at: " .. fixture_loader.get_test_repo_path())
  end
  
  local repo_path = fixture_loader.get_test_repo_path()
  local fixture_dir = fixture_loader.get_plugin_root() .. '/tests/fixtures/captured_data'
  
  -- Build command options
  local limit_arg = options.limit and ("--limit " .. options.limit) or ""
  local revset_arg = options.revset and ("--revset " .. options.revset) or ""
  
  -- Generate graph output with options
  local graph_cmd = string.format('cd "%s" && jj log --template \'"*" ++ commit_id.short(8)\' %s %s', 
                                  repo_path, limit_arg, revset_arg)
  local graph_result = vim.fn.system(graph_cmd)
  
  if vim.v.shell_error ~= 0 then
    error("Failed to generate graph output: " .. graph_result)
  end
  
  -- Generate template output with options
  local template_cmd = string.format('cd "%s" && jj log --template \'%s\' --no-graph %s %s', 
                                     repo_path, get_commit_template(), limit_arg, revset_arg)
  local template_result = vim.fn.system(template_cmd)
  
  if vim.v.shell_error ~= 0 then
    error("Failed to generate template output: " .. template_result)
  end
  
  -- Return the results for use in tests
  return {
    graph = graph_result,
    template = template_result
  }
end

-- Validate that fixture data matches current repository state
function M.validate_fixtures()
  if not fixture_loader.fixtures_available() then
    return false, "Fixture files not found"
  end
  
  if not fixture_loader.test_repo_available() then
    return false, "Test repository not available"
  end
  
  -- Generate current data
  local current_data = M.generate_fixtures_with_options()
  
  -- Load existing fixtures
  local existing_fixtures = fixture_loader.load_jj_outputs()
  
  -- Compare
  local graph_matches = current_data.graph == existing_fixtures.graph
  local template_matches = current_data.template == existing_fixtures.template
  
  if graph_matches and template_matches then
    return true, "Fixtures are up to date"
  else
    local issues = {}
    if not graph_matches then
      table.insert(issues, "graph data mismatch")
    end
    if not template_matches then
      table.insert(issues, "template data mismatch")
    end
    return false, "Fixtures need updating: " .. table.concat(issues, ", ")
  end
end

-- Print information about the test repository
function M.info()
  print("=== JJ-NVIM Test Data Generator ===")
  print("")
  
  local repo_path = fixture_loader.get_test_repo_path()
  print("Test repository: " .. repo_path)
  print("Repository available: " .. tostring(fixture_loader.test_repo_available()))
  
  local fixture_dir = fixture_loader.get_plugin_root() .. '/tests/fixtures/captured_data'
  print("Fixture directory: " .. fixture_dir)
  print("Fixtures available: " .. tostring(fixture_loader.fixtures_available()))
  
  if fixture_loader.fixtures_available() then
    local valid, msg = M.validate_fixtures()
    print("Fixtures valid: " .. tostring(valid) .. " (" .. msg .. ")")
  end
  
  print("")
  print("Usage:")
  print("  require('tests.helpers.test_data_generator').regenerate_fixtures()")
  print("  require('tests.helpers.test_data_generator').validate_fixtures()")
end

return M