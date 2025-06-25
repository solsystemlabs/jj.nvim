-- Test UTF-8 handling
local prefix = "│ │ "
print("Original: '" .. prefix .. "' length: " .. #prefix)

-- Test gsub
local result1 = prefix:gsub("[│├─╮╯╭┤~×○◆@]", "│")
print("After gsub: '" .. result1 .. "' length: " .. #result1)

-- Test manual replacement 
local result2 = prefix:gsub("│", "│") -- Should be identity
print("Manual replacement: '" .. result2 .. "' length: " .. #result2)

-- Test character by character inspection
print("Characters:")
for i = 1, #prefix do
  local byte = string.byte(prefix:sub(i, i))
  print(string.format("  %d: byte %d (%s)", i, byte, prefix:sub(i, i)))
end

-- Test with vim functions
print("Display width: " .. vim.fn.strdisplaywidth(prefix))
print("String chars: " .. vim.fn.strchars(prefix))