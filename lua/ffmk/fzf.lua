local _M = {}
local fzf_cfg = require('ffmk.config').fzf_cfg
local fmt = string.format

local script_dir = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")

--- @param name string
--- @param prompt string?
--- @param query string? runtime_ctx.cmd_cfg.query
local gen_fzf_opts = function(name, prompt, query)
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
    if type(prompt) == "string" and #prompt > 0 then
        opts = fmt("%s --prompt '%s'", opts, prompt)
    end

    -- 3. flags
    sub = fzf_cfg[name] and fzf_cfg[name].opt or {}
    for key, val in pairs(vim.tbl_extend("force", fzf_cfg.opt, sub)) do
        if type(val) == "string" then
            opts = fmt("%s %s '%s'", opts, key, val)
        elseif val then
            opts = fmt("%s %s", opts, key)
        end
    end

    -- 4. bindings
    sub = fzf_cfg[name] and fzf_cfg[name].bind or {}
    for _, val in ipairs(vim.list_extend(fzf_cfg.bind, sub)) do
        opts = fmt("%s --bind '%s'", opts, val)
    end

    -- 5. preview
    opts = fmt("%s %s", opts, fzf_cfg.preview)
    sub = fzf_cfg[name] and fzf_cfg[name].preview
    if sub then
        opts = fmt("%s %s", opts, fzf_cfg.preview)
    end

    -- 6. query
    if type(query) == "string" and #query > 0 then
        opts = fmt("%s --query '%s'", opts, query)
    end

    return opts
end

--- @param name string runtime_ctx.name
--- @param cwd string? runtime_ctx.cmd_cfg.cwd
--- @param cmd string  runtime_ctx.cmd_cfg.cmd
--- @param prompt string? runtime_ctx.cmd_cfg.prompt
--- @param query string? runtime_ctx.cmd_cfg.query
_M.run = function(name, cwd, cmd, prompt, query)
    assert(type(cmd) ~= string, "cmd must be a string")

    vim.fn.jobstart(fzf_cfg.bin, {
        cwd = vim.fn.expand(cwd or vim.fn.getcwd()),
        term = true,
        clear_env = true,
        env = {
            -- used by tool (conv, rpc_client)
            ["FFMK_LOG_DIR"] = vim.fn.stdpath("log") .. "/ffmk",
            ["FFMK_RPC_UNIX_SOCKET"] = vim.v.servername,

            ["PATH"] = fmt("%s/../../bin:%s", script_dir, vim.env.PATH),
            ["SHELL"] = vim.o.shell,
            ["FZF_DEFAULT_COMMAND"] = cmd,
            ["FZF_DEFAULT_OPTS"] = gen_fzf_opts(name, prompt, query),
        },
    })
    vim.cmd('startinsert')
end

return _M
