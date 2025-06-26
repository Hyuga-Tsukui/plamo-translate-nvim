local M = {}
local win, buf
local spinner_timer
local spinner_index = 1
local spinner_symbols = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.open()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		buf = vim.api.nvim_create_buf(false, true)
	end

	if not win or not vim.api.nvim_win_is_valid(win) then
		win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = math.floor(vim.o.columns * 0.8),
			height = math.floor(vim.o.lines * 0.8),
			row = math.floor((vim.o.lines - vim.o.lines * 0.8) / 2),
			col = math.floor((vim.o.columns - vim.o.columns * 0.8) / 2),
			border = "rounded",
			style = "minimal",
		})
	end
end

function M.clear()
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
	end
end

function M.start_spinner()
	M.clear()
	spinner_index = 1
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { spinner_symbols[spinner_index] })

	spinner_timer = vim.loop.new_timer()
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

return M
