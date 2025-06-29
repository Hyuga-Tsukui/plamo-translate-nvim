local M = {}

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

function M.translate_selection()
	local text = get_visual_selection_text()
	if not text or text == "" then
		vim.notify("No text selected", vim.log.levels.WARN)
		return
	end

	local ui = require("plamo-translate-nvim.ui")
	ui.open()
	ui.start_spinner()

	local first_chunk_received = false

	local _ = vim.system({ "plamo-translate", "--input", text }, {
		stdin = text,
		stdout = function(err, data)
			if err then
				vim.schedule(function()
					vim.notify("[plamo-translate stdout error] " .. err, vim.log.levels.ERROR)
				end)
				return
			end
			if data then
				vim.schedule(function()
					if not first_chunk_received then
						ui.stop_spinner()
						first_chunk_received = true
					end
					ui.update(data)
				end)
			end
		end,
		stderr = function(err, data)
			if err then
				vim.schedule(function()
					vim.notify("[plamo-translate stderr error] " .. err, vim.log.levels.ERROR)
				end)
			elseif data and data ~= "" then
				vim.schedule(function()
					vim.notify("[plamo-translate error] " .. data, vim.log.levels.ERROR)
				end)
			end
		end,
	})
end

return M
