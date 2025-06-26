local M = {}

local function get_visual_selection_text()
	local lines = vim.fn.getline("'<", "'>")
	if type(lines) == "string" then
		lines = { lines }
	end
	return table.concat(lines, "\n")
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
