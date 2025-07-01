-- Test regex for conflict line
local test_line = "│ ×    lokspvzr teernisse@visiostack.com 2025-06-25 17:20:45 beceecea conflict"

print("Test line: " .. test_line)

-- Test original regex (should fail)
local commit_id_1 = test_line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])$")
print("Original regex (end of line): " .. (commit_id_1 or "nil"))

-- Test new regex 
local commit_id_2 = test_line:match("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])%s*[%w%s]*$")
print("New regex (with conflict): " .. (commit_id_2 or "nil"))

-- Test simpler approach - find last 8-char hex sequence
local commit_id_3 = test_line:match(".*([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])")
print("Simpler regex (last 8-char): " .. (commit_id_3 or "nil"))

-- Test even simpler - just find any 8-char hex
for match in test_line:gmatch("([a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])") do
  print("All 8-char hex found: " .. match)
end