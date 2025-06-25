-- Debug missing commit issue
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local commands = require('jj-nvim.jj.commands')

print("=== Debug Missing Commit Issue ===")

-- Get log output 
local log_output, _ = commands.execute({'log', '--no-pager', '--limit', '8'}, { silent = true })
print("=== LOG OUTPUT ===")
print(log_output)

-- Get template output
local COMMIT_TEMPLATE = [[change_id ++ "|" ++ commit_id ++ "|" ++ change_id.short(8) ++ "|" ++ commit_id.short(8) ++ "|" ++ author.name() ++ "|" ++ author.email() ++ "|" ++ author.timestamp() ++ "|" ++ description.first_line() ++ "|" ++ if(current_working_copy, "true", "false") ++ "|" ++ if(empty, "true", "false") ++ "|" ++ if(mine, "true", "false") ++ "|" ++ if(root, "true", "false") ++ "|" ++ bookmarks.join(",") ++ "|" ++ parents.map(|p| p.commit_id().short(8)).join(",") ++ "\n"]]

local template_output, _ = commands.execute({
  'log', '--template', COMMIT_TEMPLATE, '--no-graph', '--no-pager', '--limit', '8'
}, { silent = true })

print("\n=== TEMPLATE OUTPUT ===")
print(template_output)

-- Extract commit IDs from both
print("\n=== COMMIT ID COMPARISON ===")

print("Commit IDs from log:")
local log_lines = vim.split(log_output, '\n', { plain = true })
for i, line in ipairs(log_lines) do
  local has_symbol = line:find("[@○◆×]")
  local commit_id = line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])$")
  if has_symbol and commit_id then
    print(string.format("  %s - %s", commit_id, line:sub(1, 50)))
  end
end

print("\nCommit IDs from template:")
for line in template_output:gmatch('[^\r\n]+') do
  if line ~= "" then
    local parts = vim.split(line, '|', { plain = true })
    if #parts >= 4 then
      print(string.format("  %s - %s", parts[4], parts[3]))
    end
  end
end