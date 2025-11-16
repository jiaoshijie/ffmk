vim.api.nvim_create_user_command("Ff", require("ffmk.provider").files, { nargs = 0 })
vim.api.nvim_create_user_command("Fo", function()
    require("ffmk.provider").files({
        cmd = {
            prompt = "NvimConfig❯ ",
            cwd = "~/.config/nvim",
            hidden = true,
        }
    })
end, { nargs = 0 })

