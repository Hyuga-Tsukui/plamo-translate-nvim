local M = {}

local server_handle = nil
local stdout_acc = {}

function M.start()
	if server_handle and not server_handle.completed then
		vim.notify("[plamo] server is already running", vim.log.levels.INFO)
		return
	end

	stdout_acc = {}

	server_handle = vim.system({ "plamo-translate", "server" }, {
		stderr = function(err, data)
			if err then
				vim.schedule(function()
					vim.notify("[plamo] stderr error: " .. tostring(err), vim.log.levels.ERROR)
				end)
			elseif data and data ~= "" then
				vim.schedule(function()
					-- match log levels based on content
					-- because plamo-translate server is hosted uvcorn (uvcorn outputs logs to stderr)
					local level = vim.log.levels.INFO
					if data:match("ERROR") then
						level = vim.log.levels.ERROR
					elseif data:match("WARNING") then
						level = vim.log.levels.WARN
					end
					vim.notify("[plamo] " .. data, level)
				end)
			end
		end,
	}, function(proc)
		vim.schedule(function()
			if proc.code == 0 then
				vim.notify("[plamo] server exited normally", vim.log.levels.INFO)
			else
				local output = table.concat(stdout_acc, "")
				if output:match("already running") then
					vim.notify("[plamo] server already running", vim.log.levels.INFO)
				else
					vim.notify("[plamo] server exited abnormally (code: " .. proc.code .. ")", vim.log.levels.ERROR)
				end
			end
		end)
	end)
end

function M.stop()
	if server_handle and not server_handle.completed then
		local ok, err = pcall(function()
			server_handle:kill("sigterm")
		end)
		if not ok then
			vim.schedule(function()
				vim.notify("[plamo] failed to kill server: " .. tostring(err), vim.log.levels.WARN)
			end)
		else
			vim.schedule(function()
				vim.notify("[plamo] server stopped", vim.log.levels.INFO)
			end)
		end
		server_handle = nil
	elseif server_handle and server_handle.completed then
		vim.notify("[plamo] server is already stopped", vim.log.levels.INFO)
		server_handle = nil
	else
		vim.notify("[plamo] no server to stop", vim.log.levels.INFO)
	end
end

function M.setup()
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			M.stop()
		end,
	})
end

return M
