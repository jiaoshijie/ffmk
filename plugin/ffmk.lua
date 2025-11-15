vim.api.nvim_create_user_command("Ff", require("ffmk.provider").files, { nargs = 0 })
vim.api.nvim_create_user_command("Fg", function()
    local cwd = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if vim.v.shell_error ~= 0 then
        print("Error: Not in a git repo")
        return
    end

    require("ffmk.provider").files({
        cmd = "git ls-files --others --exclude-standard --cached | uniq",
        cwd = cwd,
    })
end, { nargs = 0 })

local kit = require('kit')
local files_cmd = {}
vim.api.nvim_create_user_command("FF", function()
    require("ffmk.provider").files({
        cmd = kit.find_files_cmd(files_cmd)
    })
end, { nargs = 0 })
