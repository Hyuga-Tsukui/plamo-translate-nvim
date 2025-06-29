local M = {}

---@return string
local function get_visual_selection_text()
    local start_pos, end_pos, sel_type

    local mode = vim.fn.mode()
    if mode:match("[vV]") then
        start_pos = vim.fn.getpos("v")
        end_pos = vim.fn.getpos(".")
        sel_type = vim.fn.visualmode()
    else
        start_pos = vim.fn.getpos("'<")
        end_pos = vim.fn.getpos("'>")
        sel_type = "v"
    end
    local lines = vim.fn.getregion(start_pos, end_pos, { type = sel_type })

    local text

    for _, line in ipairs(lines) do
        if not text then
            text = line
        else
            text = text .. "\n" .. line
        end
    end

    return text
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
