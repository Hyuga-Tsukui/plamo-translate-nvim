local M = {}

function M.setup()
	require("plamo-translate-nvim.server").start()
	require("plamo-translate-nvim.commands").setup()
end

return M
