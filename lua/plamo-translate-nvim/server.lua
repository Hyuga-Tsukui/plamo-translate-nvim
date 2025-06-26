local M = {}
local Job = require("plenary.job")

local server_job

function M.start()
	if server_job and server_job:is_running() then
		return
	end

	local stdout_lines = {}

	server_job = Job:new({
		command = "plamo-translate",
		args = { "server" },
		on_stdout = function(_, data)
			if data and data ~= "" then
				table.insert(stdout_lines, data)
			end
		end,
		on_exit = function(_, exit_code)
			vim.schedule(function()
				local output = table.concat(stdout_lines, "\n")
				if output:match("already running") then
					vim.notify("[plamo-translate-nvim] plamo-translate server is already running", vim.log.levels.INFO)
				elseif exit_code == 0 then
					vim.notify("[plamo-translate-nvim] started plamo-translate server", vim.log.levels.INFO)
				else
					vim.notify(
						string.format(
							"[plamo-translate-nvim] failed to start plamo-translate server (exit code: %d)",
							exit_code
						),
						vim.log.levels.ERROR
					)
				end
			end)
		end,
	})

	server_job:start()
end

function M.stop()
	if server_job and server_job:is_running() then
		local ok = pcall(function()
			server_job:kill()
		end)
		if not ok then
			vim.notify("[plamo-translate-nvim] Failed to kill server job", vim.log.levels.WARN)
		end
	end
end

return M
