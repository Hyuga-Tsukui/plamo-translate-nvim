local M = {}

function M.setup()
	vim.api.nvim_create_user_command("PlamoTranslateSelection", function()
		require("plamo-translate-nvim.cli").translate_selection()
	end, { range = true })
end

return M
