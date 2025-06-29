local M = {}

---@return string
local function get_visual_selection_text()
	local start_pos, end_pos

	local mode = vim.fn.mode()
	local lines
	if mode:match("[vV]") then
		start_pos = vim.fn.getpos("v")
		end_pos = vim.fn.getpos(".")
		lines = vim.fn.getregion(start_pos, end_pos, { type = "v" })
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	else
		lines = { vim.fn.getline(".") }
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

local function get_visual_selection_with_position()
	local bufnr = vim.api.nvim_get_current_buf()
	local mode = vim.fn.mode()
	local start_pos, end_pos, sel_type

	if mode:match("[vV]") then
		start_pos = vim.fn.getpos("v")
		end_pos = vim.fn.getpos(".")
		sel_type = vim.fn.visualmode()
		if sel_type == "" or sel_type == nil then
			sel_type = "v"
		end

		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

		local srow, scol = start_pos[2] - 1, start_pos[3] - 1
		local erow, ecol = end_pos[2] - 1, end_pos[3] - 1
		if srow > erow or (srow == erow and scol > ecol) then
			srow, erow = erow, srow
			scol, ecol = ecol, scol
		end

		-- Fix exclusive end position
		if sel_type == "V" then
			ecol = 0
			erow = erow + 1
		else
			local end_line = vim.fn.getline(erow + 1)
			ecol = #end_line
		end

		local lines = vim.fn.getregion(start_pos, end_pos, { type = sel_type, inclusive = true })

		return {
			text = table.concat(lines, "\n"),
			bufnr = bufnr,
			start_row = srow,
			start_col = scol,
			end_row = erow,
			end_col = ecol,
			sel_type = sel_type,
		}
	else
		local row = vim.fn.line(".") - 1
		local line = vim.fn.getline(".")
		return {
			text = line,
			bufnr = bufnr,
			start_row = row,
			start_col = 0,
			end_row = row,
			end_col = #line,
			sel_type = sel_type,
		}
	end
end

function M.translate_and_replace()
	local selection = get_visual_selection_with_position()
	if not selection or not selection.text or selection.text == "" then
		vim.notify("No text selected", vim.log.levels.WARN)
		return
	end

	local ui = require("plamo-translate-nvim.ui")
	local translation_result = ""
	local has_error = false

	-- Start progress display
	ui.show_progress("🔄 Translating...")
	
	-- Highlight selection during translation
	local ns_id = vim.api.nvim_create_namespace("plamo_translate_progress")
	vim.api.nvim_buf_add_highlight(selection.bufnr, ns_id, "DiffChange", selection.start_row, selection.start_col, selection.end_col)

	vim.system({ "plamo-translate", "--input", selection.text }, {
		stdin = selection.text,
		stdout = function(err, data)
			if err then
				vim.schedule(function()
					has_error = true
					ui.update_progress("Translation error", false)
					vim.api.nvim_buf_clear_namespace(selection.bufnr, ns_id, 0, -1)
					vim.notify("Translate stdout error: " .. err, vim.log.levels.ERROR)
				end)
				return
			end
			if data then
				translation_result = translation_result .. data
			end
		end,
		stderr = function(err, data)
			if err or (data and data ~= "") then
				vim.schedule(function()
					has_error = true
					ui.update_progress("Translation error", false)
					vim.api.nvim_buf_clear_namespace(selection.bufnr, ns_id, 0, -1)
					vim.notify("Translate stderr: " .. (err or data), vim.log.levels.ERROR)
				end)
			end
		end,
	}, function(job)
		vim.schedule(function()
			-- Clear selection highlight
			vim.api.nvim_buf_clear_namespace(selection.bufnr, ns_id, 0, -1)
			
			if has_error then
				return
			end

			if job.code == 0 and translation_result ~= "" then
				local final_result = translation_result:gsub("\n$", "")
				local lines = vim.split(final_result, "\n", { plain = true })

				-- ⚠️ Append an empty string to ensure the final line ends with a newline.
				-- This is necessary because `nvim_buf_set_text()` does not implicitly insert
				-- a newline after the last line of the inserted text. Without this, the last
				-- line of the replacement may be joined with the next line in the buffer,
				-- especially when the visual selection was made in Line-wise mode (`V`).
				if selection.sel_type == "V" and lines[#lines] ~= "" then
					table.insert(lines, "")
				end

				local ok, err = pcall(function()
					vim.api.nvim_buf_set_text(
						selection.bufnr,
						selection.start_row,
						selection.start_col,
						selection.end_row,
						selection.end_col,
						lines
					)
				end)
				
				if not ok then
					ui.update_progress("Replacement failed", false)
					vim.notify("Failed to replace text: " .. tostring(err), vim.log.levels.ERROR)
				else
					ui.update_progress("Translation completed", true)
					-- Highlight the replaced text briefly
					local replaced_ns_id = vim.api.nvim_create_namespace("plamo_translate_result")
					local end_row = selection.start_row + #lines - 1
					local end_col = selection.sel_type == "V" and 0 or #lines[#lines]
					
					vim.api.nvim_buf_add_highlight(selection.bufnr, replaced_ns_id, "DiffAdd", selection.start_row, selection.start_col, end_col)
					
					-- Clear result highlight after 2 seconds
					vim.defer_fn(function()
						if vim.api.nvim_buf_is_valid(selection.bufnr) then
							vim.api.nvim_buf_clear_namespace(selection.bufnr, replaced_ns_id, 0, -1)
						end
					end, 2000)
				end
			else
				ui.update_progress("Translation failed", false)
				vim.notify("Translation failed with code: " .. job.code, vim.log.levels.ERROR)
			end
		end)
	end)
end

return M
