local _M = {}
local fzf_cfg = require('ffmk.config').fzf_cfg
local fmt = string.format

local script_dir = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")

--- @class FzfCtx
--- @field name string      runtime_ctx.name
--- @field cmd string       runtime_ctx.cmd_cfg.cmd
--- @field cwd string?      runtime_ctx.cmd_cfg.cwd
--- @field prompt string?   runtime_ctx.cmd_cfg.prompt
--- @field query string?    runtime_ctx.cmd_cfg.query
--- @field search string?   runtime_ctx.cmd_cfg.query
--- @field search_title string?   ui.gen_grep_title

--- @param ctx FzfCtx
local gen_fzf_opts = function(ctx)
    local opts, found, sub = "", false, nil

    -- 1. colors
    for key, val in pairs(fzf_cfg.colors) do
        if val then
            found = true
            opts = opts .. fmt("%s:%s,", key, val)
        end
    end
    if found then
        opts = fmt("--color '%s'", opts)
    end

    -- 2. prompt
    if type(ctx.prompt) == "string" and #ctx.prompt > 0 then
        opts = fmt("%s --prompt '%s'", opts, ctx.prompt)
    end

    -- 3. flags
    sub = fzf_cfg[ctx.name] and fzf_cfg[ctx.name].opt or {}
    for key, val in pairs(vim.tbl_extend("force", fzf_cfg.opt, sub)) do
        if type(val) == "string" then
            opts = fmt("%s %s '%s'", opts, key, val)
        elseif val then
            opts = fmt("%s %s", opts, key)
        end
    end

    -- 4. bindings
    sub = fzf_cfg[ctx.name] and fzf_cfg[ctx.name].bind or {}
    for _, val in ipairs(vim.list_extend(fzf_cfg.bind, sub)) do
        opts = fmt("%s --bind '%s'", opts, val)
    end

    -- 5. preview
    opts = fmt("%s %s", opts, fzf_cfg.preview)
    sub = fzf_cfg[ctx.name] and fzf_cfg[ctx.name].preview
    if sub then
        opts = fmt("%s %s", opts, fzf_cfg.preview)
    end

    -- 6. query
    if type(ctx.query) == "string" and #ctx.query > 0 then
        opts = fmt("%s --query %s", opts, vim.fn.shellescape(ctx.query, false))
    end

    -- 7. header
    -- NOTE: the --header=%s must not be surrounded by single quotes
    if type(ctx.search) == "string" and #ctx.search > 0 then
        opts = fmt("%s --header-border=rounded --header-label='%s' --header=%s",
                    opts, ctx.search_title, ctx.search)
    end

    return opts
end

--- @param ctx FzfCtx
_M.run = function(ctx)
    assert(type(ctx.cmd) == "string", "cmd must be a string")

    vim.fn.jobstart(fzf_cfg.bin, {
        cwd = vim.fn.expand(ctx.cwd or vim.fn.getcwd()),
        term = true,
        clear_env = true,
        env = {
            -- used by tool (conv, rpc_client)
            ["FFMK_LOG_DIR"] = vim.fn.stdpath("log") .. "/ffmk",  -- log.h
            ["FFMK_RPC_UNIX_SOCKET"] = vim.v.servername,  -- rpc_client.c

            -- `man 7 locale`
            ["LANG"] = "C",
            ["LC_ALL"] = "C",
            ["USER"] = vim.env.USER,
            ["HOME"] = vim.env.HOME,
            ["PATH"] = fmt("%s/../../bin:%s", script_dir, vim.env.PATH),
            ["SHELL"] = vim.o.shell,
            ["FZF_DEFAULT_COMMAND"] = ctx.cmd,
            ["FZF_DEFAULT_OPTS"] = gen_fzf_opts(ctx),
        },
    })
    vim.cmd('startinsert')
end

return _M
