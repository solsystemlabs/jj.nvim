#!/usr/bin/env nvim -l

-- Add lua directory to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Test script for color extraction functionality
local ansi = require('jj-nvim.utils.ansi')

-- Test 1: extract_color_and_text
print("=== Test 1: extract_color_and_text ===")
local test_text = "\27[1m\27[38;5;13mhello\27[0m world"
local colors, clean = ansi.extract_color_and_text(test_text)
print("Input: " .. test_text)
print("Colors: '" .. colors .. "'")
print("Clean text: '" .. clean .. "'")
print("")

-- Test 2: extract_field_colors
print("=== Test 2: extract_field_colors ===")
local colored_field = "CHID_START\27[1m\27[38;5;5mabc123\27[0mCHID_END"
local field_colors, field_text = ansi.extract_field_colors(colored_field, "CHID_START", "CHID_END")
print("Input: " .. colored_field)
print("Field colors: '" .. field_colors .. "'")
print("Field text: '" .. field_text .. "'")
print("")

-- Test 3: get_opening_color_codes
print("=== Test 3: get_opening_color_codes ===")
local text_with_opening_codes = "\27[1m\27[38;5;2mtext here"
local opening_codes = ansi.get_opening_color_codes(text_with_opening_codes)
print("Input: " .. text_with_opening_codes)
print("Opening codes: '" .. opening_codes .. "'")
print("")

print("Color extraction tests completed!")