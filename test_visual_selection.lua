#!/usr/bin/env lua

-- Test script for visual selection functionality
-- This script can be used to manually test the visual selection fix

local function get_visual_selection_text()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line, start_col = start_pos[2], start_pos[3]
	local end_line, end_col = end_pos[2], end_pos[3]
	
	if start_line == 0 or end_line == 0 then
		return ""
	end
	
	local lines = vim.fn.getline(start_line, end_line)
	if type(lines) == "string" then
		lines = { lines }
	end
	
	if #lines == 0 then
		return ""
	end
	
	if #lines == 1 then
		local line = lines[1]
		local selection_end = end_col
		if vim.o.selection == "inclusive" then
			selection_end = end_col
		else
			selection_end = end_col - 1
		end
		return line:sub(start_col, selection_end)
	else
		lines[1] = lines[1]:sub(start_col)
		local selection_end = end_col
		if vim.o.selection == "inclusive" then
			selection_end = end_col
		else
			selection_end = end_col - 1
		end
		lines[#lines] = lines[#lines]:sub(1, selection_end)
		return table.concat(lines, "\n")
	end
end

-- Test function to verify the selection works
local function test_selection()
	local selected_text = get_visual_selection_text()
	print("Selected text: '" .. selected_text .. "'")
	print("Length: " .. #selected_text)
end

-- Manual test instructions:
-- 1. Open this file in Neovim
-- 2. Visually select some text below
-- 3. Run :lua test_selection()
-- 4. Verify that only the selected portion is returned

-- Test data:
-- Line 1: Hello world! This is a test line for partial selection.
-- Line 2: Another test line with different content.
-- Line 3: Final line for multi-line selection testing.

return {
	get_visual_selection_text = get_visual_selection_text,
	test_selection = test_selection
}