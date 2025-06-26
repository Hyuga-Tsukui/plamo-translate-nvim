require("plamo-translate-nvim").setup()

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		require("plamo-translate-nvim.server").stop()
	end,
})
