local _M = {}
local ui = require("ffmk.ui")
local config = require("ffmk.config")
local fmt = string.format

local script_dir = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")

local gen_fzf_opts = function(ctx)
    local fzf_cfg = config.cfg.ff
    local fzf_provider_cfg = fzf_cfg[ctx.cfg.provider_name]
    local win_cfg = ctx.win_cfg
    local opts = ""
    -- 1. colors
    local found = false
    for name, val in pairs(fzf_cfg.colors) do
        if val then
            found = true
            opts = opts .. fmt("%s:%s,", name, val)
        end
    end
    if found then
        opts = fmt("--color '%s'", opts)
    end

    -- 2. prompt
    if type(ctx.cfg.prompt) == "string" and #ctx.cfg.prompt > 0 then
        opts = fmt("%s --prompt '%s'", opts, ctx.cfg.prompt)
    end

    -- 3. flags
    local sub_opt = fzf_provider_cfg and fzf_provider_cfg.opt or {}
    for name, val in pairs(vim.tbl_extend("force", fzf_cfg.opt, sub_opt)) do
        if type(val) == "string" then
            opts = fmt("%s %s '%s'", opts, name, val)
        elseif val then
            opts = fmt("%s %s", opts, name)
        end
    end

    -- TODO: 4. bindings
    opts = fmt("%s --bind 'alt-a:toggle-all,alt-g:first,alt-G:last'", opts)
    opts = fmt("%s --bind 'enter:execute-silent(rpc_client 1 {} {q} {n})'", opts)

    -- TODO: 5. preview
    if win_cfg.preview then
        opts = fmt("%s --bind 'focus:execute-silent(rpc_client 2 {} {q} {n})' --preview-window 'hidden'", opts)
    end

    return opts
end

_M.run = function(ctx, cmd)
    local fzf_cfg = config.cfg.ff
    ui.create(ctx)

    vim.fn.jobstart(fzf_cfg.fzf_bin, {
        cwd = ctx.cfg.cwd or vim.fn.getcwd(),
        term = true,
        clear_env = true,
        env = {
            -- used by tool (conv, rpc_client)
            ["FFMK_LOG_DIR"] = vim.fn.stdpath("log") .. "/ffmk",
            ["FFMK_RPC_UNIX_SOCKET"] = vim.v.servername,

            ["PATH"] = fmt("%s/../../bin:%s", script_dir, vim.env.PATH),
            ["SHELL"] = vim.o.shell,
            ["FZF_DEFAULT_COMMAND"] = cmd,
            ["FZF_DEFAULT_OPTS"] = gen_fzf_opts(ctx),
        },
    })

    vim.cmd('startinsert')
end

return _M
