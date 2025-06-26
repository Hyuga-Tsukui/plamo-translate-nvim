local M = {}
local uv = vim.uv

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

	local stdout = uv.new_pipe(false)
	local stderr = uv.new_pipe(false)

	local first_chunk_received = false

	local handle
	handle = uv.spawn("plamo-translate", {
		args = { "--input", text },
		stdio = { nil, stdout, stderr },
	}, function()
		stdout:close()
		stderr:close()
		if handle then
			handle:close()
		end
	end)

	stdout:read_start(function(err, data)
		assert(not err, err)
		if data then
			vim.schedule(function()
				if not first_chunk_received then
					ui.stop_spinner()
					first_chunk_received = true
				end
				ui.update(data)
			end)
		end
	end)

	stderr:read_start(function(err, data)
		assert(not err, err)
		if data then
			vim.schedule(function()
				vim.notify("[plamo-translate error] " .. data, vim.log.levels.ERROR)
			end)
		end
	end)
end

return M
