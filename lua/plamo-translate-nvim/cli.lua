local M = {}

-- Constants
local CONSTANTS = {
	COMMAND = "plamo-translate",
	VISUAL_MODES = "[vV]",
	ESCAPE_KEY = "<Esc>",
}

-- Error messages
local ERROR_MESSAGES = {
	NO_TEXT_SELECTED = "No text selected",
	STDOUT_ERROR = "[plamo-translate stdout error] ",
	STDERR_ERROR = "[plamo-translate stderr error] ",
	TRANSLATION_ERROR = "[plamo-translate error] ",
	REPLACEMENT_FAILED = "Failed to replace text: ",
	TRANSLATION_FAILED = "Translation failed with code: ",
}

-- Progress messages
local PROGRESS_MESSAGES = {
	TRANSLATING = "🔄 Translating...",
	TRANSLATION_COMPLETED = "Translation completed",
	TRANSLATION_FAILED = "Translation failed",
	REPLACEMENT_FAILED = "Replacement failed",
}

-- Utility functions for selection handling

---@return boolean
local function is_in_visual_mode()
	return vim.fn.mode():match(CONSTANTS.VISUAL_MODES) ~= nil
end

---@return integer[], integer[], string
local function get_visual_mode_info()
	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	local sel_type = vim.fn.visualmode()

	if sel_type == "" or sel_type == nil then
		sel_type = "v"
	end

	return start_pos, end_pos, sel_type
end

---@param start_pos table
---@param end_pos table
---@return number, number, number, number
local function normalize_selection_bounds(start_pos, end_pos)
	local srow, scol = start_pos[2] - 1, start_pos[3] - 1
	local erow, ecol = end_pos[2] - 1, end_pos[3] - 1

	if srow > erow or (srow == erow and scol > ecol) then
		srow, erow = erow, srow
		scol, ecol = ecol, scol
	end

	return srow, scol, erow, ecol
end

---@param sel_type string
---@param erow number
---@return number, number
local function adjust_selection_end(sel_type, erow)
	if sel_type == "V" then
		return erow + 1, 0
	else
		local end_line = vim.fn.getline(erow + 1)
		return erow, #end_line
	end
end

---@return string
local function get_visual_selection_text()
	local lines
	if is_in_visual_mode() then
		local start_pos, end_pos = get_visual_mode_info()
		lines = vim.fn.getregion(start_pos, end_pos, { type = "v" })
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(CONSTANTS.ESCAPE_KEY, true, false, true), "n", false)
	else
		lines = { vim.fn.getline(".") }
	end
	return table.concat(lines, "\n")
end

-- Error handling utilities

---@param message string
local function notify_error(message)
	vim.notify(message, vim.log.levels.ERROR)
end

---@param message string
local function notify_warning(message)
	vim.notify(message, vim.log.levels.WARN)
end

---@param err string|nil
---@param data string|nil
---@param prefix string
local function handle_command_error(err, data, prefix)
	if err then
		vim.schedule(function()
			notify_error(prefix .. err)
		end)
	elseif data and data ~= "" then
		vim.schedule(function()
			notify_error(prefix .. data)
		end)
	end
end

-- Translation executor

---@param text string
---@param on_stdout function function Callback for stdout (executed asynchronously).
---@param on_stderr function function Callback for stdout (executed asynchronously).
---@param on_exit function|nil function Callback for stdout (executed asynchronously).
---@return table
local function execute_translation_ex_process(text, on_stdout, on_stderr, on_exit)
	return vim.system({ CONSTANTS.COMMAND, "--input", text }, {
		stdin = text,
		stdout = on_stdout,
		stderr = on_stderr,
	}, on_exit)
end

---@param translation_result string
---@param selection table
---@return boolean, string|nil
local function replace_text_in_buffer(translation_result, selection)
	local final_result = translation_result:gsub("\n$", "")
	local lines = vim.split(final_result, "\n", { plain = true })

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

	return ok, err
end

function M.translate_selection()
	local text = get_visual_selection_text()
	if not text or text == "" then
		notify_warning(ERROR_MESSAGES.NO_TEXT_SELECTED)
		return
	end

	local ui = require("plamo-translate-nvim.ui")
	ui.open()
	ui.start_spinner()

	local first_chunk_received = false

	execute_translation_ex_process(text, function(err, data)
		if err then
			handle_command_error(err, nil, ERROR_MESSAGES.STDOUT_ERROR)
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
	end, function(err, data)
		handle_command_error(err, data, ERROR_MESSAGES.STDERR_ERROR)
	end)
end

---@return table|nil
local function get_visual_selection_with_position()
	local bufnr = vim.api.nvim_get_current_buf()

	if is_in_visual_mode() then
		local start_pos, end_pos, sel_type = get_visual_mode_info()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(CONSTANTS.ESCAPE_KEY, true, false, true), "n", false)

		local srow, scol, erow, ecol = normalize_selection_bounds(start_pos, end_pos)
		erow, ecol = adjust_selection_end(sel_type, erow)

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
			sel_type = nil,
		}
	end
end

function M.translate_and_replace()
	local selection = get_visual_selection_with_position()
	if not selection or not selection.text or selection.text == "" then
		notify_warning(ERROR_MESSAGES.NO_TEXT_SELECTED)
		return
	end

	local ui = require("plamo-translate-nvim.ui")
	local translation_result = ""
	local has_error = false

	ui.show_progress(PROGRESS_MESSAGES.TRANSLATING)

	execute_translation_ex_process(selection.text, function(err, data)
		if err then
			vim.schedule(function()
				has_error = true
				ui.update_progress(PROGRESS_MESSAGES.TRANSLATION_FAILED, false)
				notify_error(ERROR_MESSAGES.STDOUT_ERROR .. err)
			end)
			return
		end
		if data then
			translation_result = translation_result .. data
		end
	end, function(err, data)
		if err or (data and data ~= "") then
			vim.schedule(function()
				has_error = true
				ui.update_progress(PROGRESS_MESSAGES.TRANSLATION_FAILED, false)
				notify_error(ERROR_MESSAGES.STDERR_ERROR .. (err or data))
			end)
		end
	end, function(job)
		vim.schedule(function()
			if has_error then
				return
			end

			if job.code == 0 and translation_result ~= "" then
				local ok, err = replace_text_in_buffer(translation_result, selection)

				if not ok then
					ui.update_progress(PROGRESS_MESSAGES.REPLACEMENT_FAILED, false)
					notify_error(ERROR_MESSAGES.REPLACEMENT_FAILED .. tostring(err))
				else
					ui.update_progress(PROGRESS_MESSAGES.TRANSLATION_COMPLETED, true)
				end
			else
				ui.update_progress(PROGRESS_MESSAGES.TRANSLATION_FAILED, false)
				notify_error(ERROR_MESSAGES.TRANSLATION_FAILED .. job.code)
			end
		end)
	end)
end

return M
