local M = {}

function M.setup()
	local ok, err_or_job = pcall(vim.system, { "plamo-translate", "-v" }, { text = true }, function(job)
		if job.code == 0 then
			vim.notify("plamo-translate-nvim is using " .. job.stdout:gsub("\n", ""), vim.log.levels.INFO)
		else
			vim.notify(("code: %d, stderr: %s"):format(job.code, job.stderr:gsub("\n", " ")), vim.log.levels.ERROR)
			return
		end
	end)

	if not ok then
		local err = err_or_job
		vim.notify(("failed to spawn: %s"):format(err), vim.log.levels.ERROR)
		return
	end

	require("plamo-translate-nvim.server").setup()
	require("plamo-translate-nvim.server").start()
	require("plamo-translate-nvim.commands").setup()
end

return M
