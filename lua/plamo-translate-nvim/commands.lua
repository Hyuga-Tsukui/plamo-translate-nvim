local M = {}

function M.setup()
    vim.api.nvim_create_user_command("PlamoTranslateSelection", function()
        require("plamo-translate-nvim.cli").translate_selection()
    end, { range = true })

    vim.api.nvim_create_user_command("PlamoTranslateServerStop", function()
        require("plamo-translate-nvim.server").stop()
    end, {})

    vim.api.nvim_create_user_command("PlamoTranslateServerStart", function()
        require("plamo-translate-nvim.server").start()
    end, {})
end

return M
