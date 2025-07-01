-- Debug commit ID extraction
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local commands = require('jj-nvim.jj.commands')

print("=== Debug Commit ID Extraction ===")

-- Get log output
local log_output, err = commands.execute({'log', '--no-pager', '--limit', '3'}, { silent = true })
if not log_output then
  print("Error: " .. err)
  return
end

print("Raw log output:")
print(log_output)
print("\nExtracting commit IDs:")

local lines = vim.split(log_output, '\n', { plain = true })
for i, line in ipairs(lines) do
  if line:find("[@○◆×]") then
    local commit_id = line:match("([a-f0-9]+)%s*$")
    print(string.format("Line %d: commit_id='%s' | full_line='%s'", i, commit_id or "nil", line))
  end
end

print("\nTemplate data commit IDs:")
local data_output, err = commands.execute({
  'log', '--template', 'change_id.short(8) ++ "|" ++ commit_id.short(8) ++ "\n"',
  '--no-graph', '--no-pager', '--limit', '3'
}, { silent = true })

if data_output then
  for line in data_output:gmatch('[^\r\n]+') do
    if line ~= "" then
      local parts = vim.split(line, '|', { plain = true })
      print(string.format("Template: change=%s commit=%s", parts[1] or "nil", parts[2] or "nil"))
    end
  end
end