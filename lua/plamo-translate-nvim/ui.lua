local M = {}
local win, buf
local spinner_timer
local spinner_index = 1
local spinner_symbols = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- Progress floating window variables
local progress_win, progress_buf
local progress_timer
local progress_start_time

function M.open()
	if buf and vim.api.nvim_buf_is_valid(buf) then
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	if win and vim.api.nvim_win_is_valid(win) then
		return
	end

	vim.cmd("botright split")
	win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
end

function M.close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
		win = nil
	end
end

function M.toggle()
	if win and vim.api.nvim_win_is_valid(win) then
		M.close()
	else
		M.open()
	end
end

function M.clear()
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
	end
end

function M.start_spinner()
	M.open()
	M.clear()
	spinner_index = 1
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { spinner_symbols[spinner_index] })

	spinner_timer = vim.loop.new_timer()
	if not spinner_timer then
		error("Failed to create spinner timer")
	end
	spinner_timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			spinner_index = (spinner_index % #spinner_symbols) + 1
			if buf and vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_set_lines(buf, 0, 1, false, { spinner_symbols[spinner_index] })
			end
		end)
	)
end

function M.stop_spinner()
	if spinner_timer then
		spinner_timer:stop()
		spinner_timer:close()
		spinner_timer = nil
	end
	M.clear()
end

function M.update(content)
	if not content or content == "" then
		return
	end

	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		M.open()
	end

	local chunks = vim.split(content, "\n", { plain = true })
	local last_line_index = vim.api.nvim_buf_line_count(buf) - 1
	local last_line = vim.api.nvim_buf_get_lines(buf, last_line_index, last_line_index + 1, false)[1] or ""

	vim.api.nvim_buf_set_lines(buf, last_line_index, last_line_index + 1, false, { last_line .. chunks[1] })

	for i = 2, #chunks do
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { chunks[i] })
	end
end

-- Progress floating window functions
function M.show_progress(message)
	-- Close existing progress window
	M.hide_progress()
	
	-- Create buffer for progress display
	progress_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[progress_buf].buftype = "nofile"
	vim.bo[progress_buf].bufhidden = "wipe"
	vim.bo[progress_buf].swapfile = false
	
	-- Set initial content
	vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, { message or "🔄 Translating..." })
	
	-- Calculate window position (center of screen)
	local width = 30
	local height = 1
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	
	-- Create floating window
	progress_win = vim.api.nvim_open_win(progress_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Translation Progress ",
		title_pos = "center"
	})
	
	-- Set window options
	vim.wo[progress_win].winhl = "Normal:Normal,FloatBorder:FloatBorder"
	
	-- Start timer for progress animation
	progress_start_time = vim.loop.hrtime()
	local progress_spinner_index = 1
	
	progress_timer = vim.loop.new_timer()
	if progress_timer then
		progress_timer:start(0, 200, vim.schedule_wrap(function()
			if not progress_win or not vim.api.nvim_win_is_valid(progress_win) then
				M.hide_progress()
				return
			end
			
			-- Calculate elapsed time
			local elapsed_ms = math.floor((vim.loop.hrtime() - progress_start_time) / 1000000)
			local elapsed_sec = elapsed_ms / 1000
			
			-- Update spinner
			progress_spinner_index = (progress_spinner_index % #spinner_symbols) + 1
			local spinner = spinner_symbols[progress_spinner_index]
			
			-- Update progress message
			local progress_msg = string.format("%s Translating... (%.1fs)", spinner, elapsed_sec)
			
			if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
				vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, { progress_msg })
			end
		end))
	end
end

function M.hide_progress()
	-- Stop timer
	if progress_timer then
		progress_timer:stop()
		progress_timer:close()
		progress_timer = nil
	end
	
	-- Close window
	if progress_win and vim.api.nvim_win_is_valid(progress_win) then
		vim.api.nvim_win_close(progress_win, true)
		progress_win = nil
	end
	
	-- Clear buffer reference
	progress_buf = nil
	progress_start_time = nil
end

function M.update_progress(message, success)
	if not progress_win or not vim.api.nvim_win_is_valid(progress_win) then
		return
	end
	
	local icon = success and "✅" or "❌"
	local final_message = string.format("%s %s", icon, message)
	
	if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
		vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, { final_message })
	end
	
	-- Auto-close after a short delay
	vim.defer_fn(function()
		M.hide_progress()
	end, 1500)
end

return M
