local _M = {}
local fmt = string.format
local default_cfg = require('ffmk.config')
local ui = require('ffmk.ui')
local kit = require('ffmk.kit')
local ff = require('ffmk.fzf')
local action = require('ffmk.action')

--- @class Loc
--- @field path string?
--- @field row integer?
--- @field col integer?
--- @field helptag table?  { tag = "", pattern = "" }
--- @field ft string? filetype

--- @class QfLoc
--- @field filename string
--- @field lnum integer
--- @field col integer?
--- @field text string

-- { fzf, rg, fd, ctags, gnu_global }
local rt_env = { ns = { preview_ns = nil, preview_cursor_ns = nil } }

local ctx = {
    env_weak_ref = nil,

    target_winid = nil,
    query = nil,
    loc = nil,  --- @type Loc

    name = nil,
    ui_cfg = nil,
    cmd_cfg = nil,

    bufnr = nil,
    preview_bufs = nil,  -- { "ffmk" = bufnr, "abs_path" = bufnr }

    winid = nil,
    preview_winid = nil,
}

local rt_func_map = {}

--- @param tools table?  { rg, fd, ctags, gnu_global }
--- @return boolean
local validate_env = function(tools)
    tools = tools or {}
    -- 1. if there has been already an opened instance
    if ctx.winid ~= nil then
        -- close the previous one
        _M.release(true, true, true)
    end

    -- 2. if the focused window is command line
    if vim.fn.win_gettype() == "command" then
        kit.echo_err_msg("Unable to open from command-line window: `:h E11`")
        return false
    end

    -- NOTE: i don't know which version is suitable, so just using the versions when i write this plugin

    -- 3. if fzf version not match
    if rt_env.fzf == nil then
        local major, minor, _ = kit.get_cmd_version('fzf', '--version')
        rt_env.fzf = major ~= nil and (major > 0 or minor >= 65)
    end

    if rt_env.fzf == false then
        kit.echo_err_msg("fzf version is below 0.65.0")
        return false
    end

    -- 4. if rg version not match
    if tools.rg and rt_env.rg == nil then
        local major, _, _ = kit.get_cmd_version('rg', '--version')
        rt_env.rg = major ~= nil and major >= 13
    end
    if tools.rg and rt_env.rg == false then
        kit.echo_err_msg("ripgrep version is below 13.0.0")
        return false
    end

    -- 5. if fd version not match, this will not fail, but will use rg instead
    if tools.fd and rt_env.fd == nil then
        local major, minor, _ = kit.get_cmd_version('fd', '--version')
        rt_env.fd = major ~= nil and (major > 8 or (major == 7 and minor >= 3))
    end

    -- 6. check ctags
    if tools.ctags and rt_env.ctags == nil then
        local major, minor, _ = kit.get_cmd_version('ctags', '--version')
        rt_env.ctags = major ~= nil and (major > 5 or (major == 5 and minor >= 9))
    end
    if tools.ctags and rt_env.ctags == false then
        kit.echo_err_msg("ctags version is below 5.9.0")
        return false
    end

    -- 7. check gnu_global
    if tools.gnu_global and rt_env.gnu_global == nil then
        local major, minor, _ = kit.get_cmd_version('global', '--version')
        rt_env.gnu_global = major ~= nil and (major > 6 or (major == 6 and minor >= 6))
    end
    if tools.gnu_global and rt_env.gnu_global == false then
        kit.echo_err_msg("gnu-global version is below 6.6.0")
        return false
    end

    if not rt_env.ns.preview_ns then
        rt_env.ns.preview_ns = vim.api.nvim_create_namespace("ffmk_ui_preview_ns")
    end
    if not rt_env.ns.preview_cursor_ns then
        rt_env.ns.preview_cursor_ns = vim.api.nvim_create_namespace("ffmk_ui_preview_cursor_ns")
    end

    return true
end

--- @param cfg table? ctx.ui_cfg
local config_ui_cfg = function(cfg)
    ctx.ui_cfg = vim.tbl_extend('force', default_cfg.ui_cfg, cfg or {})
end

--- @param name string ctx.name
--- @param cfg table? ctx.cmd_cfg
local config_cmd_cfg = function(name, cfg)
    ctx.name = name;
    ctx.cmd_cfg = vim.tbl_extend('force', default_cfg.cmd_cfg[name], cfg or {})
end

local set_target_winid = function()
    ctx.target_winid = vim.fn.win_getid()
end

--- @param cfg table? { ui = {}, cmd = {} }
--- @param tools table?
--- @return boolean
_M.setup = function(name, cfg, tools)
    if not validate_env(tools) then
        return false
    end
    ctx.env_weak_ref = rt_env

    set_target_winid()
    config_ui_cfg(cfg and cfg.ui)
    config_cmd_cfg(name, cfg and cfg.cmd)

    return true
end

_M.run = function()
    assert(type(rt_func_map[ctx.name]) == "function", "Provider function not found")
    rt_func_map[ctx.name]()
end

_M.release = function(exit, main, preview)
    kit.clear_highlighted_cursor(rt_env.ns.preview_cursor_ns)
    if main then
        kit.win_delete(ctx.winid, true)
        kit.buf_delete(ctx.bufnr)
        ctx.winid = nil
        ctx.bufnr = nil
    end

    if preview then
        kit.win_delete(ctx.preview_winid, true)
        ctx.preview_winid = nil
    end

    if exit then
        ctx.env_weak_ref = nil
        ctx.target_winid = nil
        ctx.name = nil
        ctx.ui_cfg = nil
        ctx.cmd_cfg = nil
        ctx.query = nil
        ctx.loc = nil

        -- NOTE: using coroutine and defer_fn togather to clear the preview buf list
        local bufs = ctx.preview_bufs  -- move the ownership
        ctx.preview_bufs = nil
        local delete_preview_bufs_co = coroutine.create(function(resume_callback)
            if not bufs then return end

            local count = 0;
            for _, bufnr in pairs(bufs) do
                kit.buf_delete(bufnr)
                count = count + 1
                -- clear 25 bufs at once
                if count == 25 then
                    count = 0
                    resume_callback()
                    coroutine.yield()
                end
            end
        end)
        --- The first resume, which has no corresponding yield waiting for it,
        --- passes its extra arguments as arguments to the coroutine main function.
        ---                                              9.1 – Coroutine Basics
        coroutine.resume(delete_preview_bufs_co, function()
            vim.defer_fn(function()
                -- NOTE: The logic is straightforward,
                -- so checking the coroutine status is unnecessary.
                coroutine.resume(delete_preview_bufs_co)
            end, 50)
        end)
    end
end

------------------------------- provider -------------------------------------

--- @param cfg table ctx.cmd_cfg
--- @return string
local gen_files_cmd = function(cfg)
    if type(cfg.cmd) ~= "string" then
        if vim.fn.executable('fd') == 1 and rt_env.fd == true then
            cfg.cmd = "fd --color=never --type f --type l --exclude '.git'"
        else
            cfg.cmd = "rg --color=never --files -g '!.git'"
        end
    end

    local cmd = fmt("%s", cfg.cmd)

    -- options
    cmd = cfg.follow and fmt("%s -L", cmd) or cmd
    cmd = cfg.hidden and fmt("%s --hidden", cmd) or cmd
    cmd = cfg.no_ignore and fmt("%s --no-ignore", cmd) or cmd

    if cfg.filename_first then
        cmd = fmt("%s | conv %d", cmd, default_cfg.conv_fc.files)
    end

    return cmd
end

--- @param cfg table ctx.cmd_cfg
--- @return string?
local gen_grep_cmd = function(cfg)
    if type(cfg.query) ~= "string" or #cfg.query == 0 then
        kit.echo_err_msg("`grep` requires a query string")
        return nil
    end
    local cmd = "rg --color=always --heading --line-number --column --max-columns=4096"

    -- commen options
    cmd = cfg.follow and fmt("%s -L", cmd) or cmd
    cmd = cfg.hidden and fmt("%s --hidden", cmd) or cmd
    cmd = cfg.no_ignore and fmt("%s --no-ignore", cmd) or cmd

    -- options
    cmd = cfg.smart_case and fmt("%s --smart-case", cmd) or fmt("%s --case-sensitive", cmd)
    cmd = cfg.fixed_string and fmt("%s -F", cmd) or cmd
    cmd = cfg.whole_word and fmt("%s -w", cmd) or cmd

    -- extra options
    if type(cfg.extra_options) == "table" and #cfg.extra_options > 0 then
        cmd = fmt("%s %s", cmd, table.concat(cfg.extra_options, ' '))
    end

    -- NOTE: -e: useful to protect querys starting with ´-´.
    cmd = fmt([[%s -e %s | conv %d]], cmd, vim.fn.shellescape(cfg.query, false),
                default_cfg.conv_fc.grep)

    return cmd
end

--- @param cfg table ctx.cmd_cfg
--- @return string?
local gen_helptags_cmd = function(cfg)
    local _ = cfg
    local cmd = fmt("conv %d", default_cfg.conv_fc.helptags)
    local tagfiles = vim.fn.globpath(vim.o.runtimepath, 'doc/tags', true, true)

    if #tagfiles == 0 then
        return nil
    end

    for _, tagfile in ipairs(tagfiles) do
        cmd = fmt("%s %s", cmd, vim.fn.shellescape(tagfile, false))
    end

    return cmd
end

--- @param cfg table ctx.cmd_cfg
--- @return string?
local gen_ctags_cmd = function(cfg)
    local cmd = "ctags -x"

    if not cfg.path then
        cfg.path = vim.fn.expand("%:p")
    end

    if #cfg.path == 0 or cfg.path:sub(1, 1) ~= '/' then
        kit.echo_err_msg("no file path specified")
        return nil
    end

    if type(cfg.options) == "table" and #cfg.options > 0 then
        cmd = fmt("%s %s", cmd, table.concat(cfg.options, ' '))
    end

    cmd = fmt("%s %s | conv %d | sort -n", cmd, vim.fn.shellescape(cfg.path, false),
                default_cfg.conv_fc.ctags)

    return cmd
end

--- @param cfg table ctx.cmd_cfg
--- @return string?
local gen_gnu_global_cmd = function(cfg)
    if not cfg.feat then
        kit.echo_err_msg("gnu global `feat` not specified")
        return nil
    end

    local isfile = cfg.feat == default_cfg.gnu_global_feats.file_symbols

    if type(cfg.query) ~= "string" or #cfg.query == 0 then
        if isfile then
            cfg.query = vim.fn.expand("%:p")
            if #cfg.query == 0 or cfg.query:sub(1, 1) ~= '/' then
                kit.echo_err_msg("no file path specified")
                return nil
            end
        else
            kit.echo_err_msg("query string not specified")
            return nil
        end
    end

    local cmd = "global -q -F --color=always --result=ctags-mod --path-style=relative"

    if cfg.conf then
        cmd = fmt("%s --gtagsconf %s", cmd, vim.fn.shellescape(cfg.conf, false))
    end
    if cfg.label then
        cmd = fmt("%s --gtagslabel %s", cmd, vim.fn.shellescape(cfg.label, false))
    end

    if cfg.cwd then
        cmd = fmt("%s -C %s", cmd, vim.fn.shellescape(cfg.cwd, false))
    end

    if not isfile then
        cmd = cfg.ignore_case and fmt("%s -i", cmd) or fmt("%s -M", cmd)
        cmd = cfg.fixed_string and fmt("%s --literal", cmd) or cmd
    end

    cmd = fmt("%s %s %s %s | conv %d", cmd, cfg.feat, isfile and "" or "-e",
                vim.fn.shellescape(cfg.query, false), default_cfg.conv_fc.gnu_global)

    return cmd
end

--- @param bufnr integer
local set_keymaps = function(bufnr)
    --- @param mode string
    --- @return table
    local get_provider_specific_binds = function(mode)
        if not default_cfg.keymaps_cfg[ctx.name] then return {} end
        return default_cfg.keymaps_cfg[ctx.name][mode] or {}
    end

    for mode, keymaps in pairs(default_cfg.keymaps_cfg.global) do
        local binds = vim.tbl_extend("force", keymaps, get_provider_specific_binds(mode))
        for key, bind in pairs(binds) do
            vim.keymap.set(mode, key, function()
                action[bind](ctx, _M)
            end, { buffer = bufnr })
        end
    end
end

--- @param bufnr integer
local set_events = function(bufnr)
    local group = vim.api.nvim_create_augroup("ffmk_window_event", { clear = true })
    vim.api.nvim_create_autocmd("VimResized", {
        group = group,
        buffer = bufnr,
        callback = function()
            ui.render(ctx)
        end
    })
    -- NOTE: maybe using BufDelete, BufWipeout, but WinClosed works fine
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        buffer = bufnr,
        callback = function()
            _M.release(true, true, true)
        end
    })
end

local prepare_buffers = function()
    if not ctx.bufnr or not vim.api.nvim_buf_is_valid(ctx.bufnr) then
        ctx.bufnr = vim.api.nvim_create_buf(false, true)
        set_keymaps(ctx.bufnr)
        set_events(ctx.bufnr)
    end
    ctx.preview_bufs = ctx.preview_bufs or {}
    if not ctx.preview_bufs["ffmk"]
        or not vim.api.nvim_buf_is_valid(ctx.preview_bufs["ffmk"]) then
        ctx.preview_bufs["ffmk"] = vim.api.nvim_create_buf(false, true)
    end
end

rt_func_map.files = function()
    -- 1. create bufers
    prepare_buffers()
    -- 2. create ui
    ui.render(ctx)
    -- 3. run fuzzy finder
    ff.run({
        name = ctx.name,
        cmd = gen_files_cmd(ctx.cmd_cfg),
        cwd = ctx.cmd_cfg.cwd,
        prompt = ctx.cmd_cfg.prompt,
        query = ctx.query,
    })
end

rt_func_map.grep = function()
    local cmd = gen_grep_cmd(ctx.cmd_cfg)
    if not cmd then return end
    -- 1. create bufers
    prepare_buffers()
    -- 2. create ui
    ui.render(ctx)
    -- 3. run fuzzy finder
    ff.run({
        name = ctx.name,
        cmd = cmd,
        cwd = ctx.cmd_cfg.cwd,
        prompt = ctx.cmd_cfg.prompt,
        query = ctx.query,
        search = vim.fn.shellescape(ctx.cmd_cfg.query, false),
        search_title = ui.gen_grep_title(ctx.cmd_cfg),
    })
end

rt_func_map.helptags = function()
    local cmd = gen_helptags_cmd(ctx.cmd_cfg)
    if not cmd then return end
    -- 1. create bufers
    prepare_buffers()
    -- 2. create ui
    ui.render(ctx)
    -- 3. run fuzzy finder
    ff.run({
        name = ctx.name,
        cmd = cmd,
        prompt = ctx.cmd_cfg.prompt,
        query = ctx.query,
    })
end

rt_func_map.ctags = function()
    local cmd = gen_ctags_cmd(ctx.cmd_cfg)
    if not cmd then return end
    -- 1. create bufers
    prepare_buffers()
    -- 2. create ui
    ui.render(ctx)
    -- 3. run fuzzy finder
    ff.run({
        name = ctx.name,
        cmd = cmd,
        prompt = ctx.cmd_cfg.prompt,
        query = ctx.query,
    })
end

rt_func_map.gnu_global = function()
    local cmd = gen_gnu_global_cmd(ctx.cmd_cfg)
    if not cmd then return end

    -- NOTE: if there is only one definition, directly jump to it
    if ctx.cmd_cfg.auto_jump_definition
        and ctx.cmd_cfg.feat == default_cfg.gnu_global_feats.definition
        and kit.gnu_global_definition(cmd, ctx.cmd_cfg.cwd, ctx.target_winid) then
        _M.release(true, true, true)
        return
    end

    -- 1. create bufers
    prepare_buffers()
    -- 2. create ui
    ui.render(ctx)
    -- 3. run fuzzy finder
    ff.run({
        name = ctx.name,
        cmd = cmd,
        cwd = ctx.cmd_cfg.cwd,
        prompt = ctx.cmd_cfg.prompt,
        query = ctx.query,
        search = vim.fn.shellescape(ctx.cmd_cfg.query, false),
        search_title = ui.gen_gnu_global_title(ctx.cmd_cfg),
    })
end

---------------------------------- rpc ---------------------------------------

--- @param fc integer
--- @param arg string
--- @return Loc
local get_loc_from_fc = function(fc, arg)
    local path, row, col, helptag, ft

    if fc == default_cfg.rpc_fc.files_enter
        or fc == default_cfg.rpc_fc.files_preview then
        path = ctx.cmd_cfg.filename_first
                and arg:gsub("([^\t]+)\t(.+)", "%2/%1") or arg
    elseif fc == default_cfg.rpc_fc.grep_enter
        or fc == default_cfg.rpc_fc.grep_send2qf  -- NOTE: if only select one item, just open it
        or fc == default_cfg.rpc_fc.grep_preview then
        local b, e = string.find(arg, "\28")
        path = string.sub(arg, 1, b - 1)
        row, col, _ = string.match(string.sub(arg, e + 1), ":(%d+):(%d+):(.+)")
    elseif fc == default_cfg.rpc_fc.helptags_enter
        or fc == default_cfg.rpc_fc.helptags_preview then
        local args = vim.fn.split(arg, "\28")
        path = args[2]
        helptag = { tag = args[1], pattern = args[3] }
        ft = "help"
    elseif fc == default_cfg.rpc_fc.ctags_enter
        or fc == default_cfg.rpc_fc.ctags_preview then
        path = ctx.cmd_cfg.path
        row = arg
    elseif fc == default_cfg.rpc_fc.ctags_send2qf then  -- the format is different
        path = ctx.cmd_cfg.path
        row = vim.fn.split(arg, "\28")[1]
    elseif fc == default_cfg.rpc_fc.gnu_global_enter
        or fc == default_cfg.rpc_fc.gnu_global_send2qf
        or fc == default_cfg.rpc_fc.gnu_global_preview then
        local b, e = string.find(arg, "\28")
        path = string.sub(arg, 1, b - 1)
        row, _ = string.match(string.sub(arg, e + 1), ":(%d+):(.+)")
    else
        kit.echo_err_msg("Invalid function code")
    end

    return {
        path = kit.abs_path(ctx.cmd_cfg.cwd, path),
        row = row and tonumber(row),
        col = col and tonumber(col) - 1,  -- NOTE: maybe this will never fail
        helptag = helptag,
        ft = ft,
    }
end

--- @param fc integer
--- @param arg table
--- @return QfLoc[]
local get_qfloc_from_fc = function(fc, arg)
    local qflist = {}
    local filename, lnum, col, text
    if fc == default_cfg.rpc_fc.grep_send2qf then
        for _, val in ipairs(arg) do
            local b, e = string.find(val, "\28")
            filename = string.sub(val, 1, b - 1)
            lnum, col, text = string.match(string.sub(val, e + 1), ":(%d+):(%d+):(.+)")
            table.insert(qflist, {
                filename = kit.abs_path(ctx.cmd_cfg.cwd, filename),
                lnum = lnum,
                col = col,
                text = text,
            })
        end
    elseif fc == default_cfg.rpc_fc.ctags_send2qf then
        for _, val in ipairs(arg) do
            local args = vim.fn.split(val, "\28")
            table.insert(qflist, {
                filename = ctx.cmd_cfg.path,
                lnum = args[1],
                text = args[2],
            })
        end
    elseif fc == default_cfg.rpc_fc.gnu_global_send2qf then
        for _, val in ipairs(arg) do
            local b, e = string.find(val, "\28")
            filename = string.sub(val, 1, b - 1)
            lnum, text = string.match(string.sub(val, e + 1), ":(%d+):(.+)")
            table.insert(qflist, {
                filename = kit.abs_path(ctx.cmd_cfg.cwd, filename),
                lnum = lnum,
                text = text,
            })
        end
    else
        kit.echo_err_msg("Invalid function code")
    end
    return qflist
end

--- @param fc integer
--- @param args table
_M.rpc_quit = function(fc, args)
    local _, _ = fc, args
    _M.release(true, true, true)
end

--- @param fc integer
--- @param args table
_M.rpc_query = function(fc, args)
    local _ = fc
    ctx.query = args[1]
end

--- @param fc integer
--- @param args table
_M.rpc_edit_or_send2qf = function(fc, args)
    kit.goto_winid(ctx.target_winid)
    local selected = table.remove(args, #args)
    if #selected == 0 then
        _M.release(true, true, true)
        return
    end

    if #args == 1 then
        kit.edit(get_loc_from_fc(fc, args[1]))
    elseif #args > 1 then
        local qflist = get_qfloc_from_fc(fc, args)
        if #qflist > 0 then
            vim.fn.setqflist(qflist, 'r')
            vim.cmd('copen | cfirst')
        end
    end

    _M.release(true, true, true)
end

_M.rpc_preview = function(fc, args)
    -- NOTE: remove the query from the arguments.
    -- query is not used in the preview, it exists only to refresh
    -- the preview window when there is not item in fzf.
    local _ = table.remove(args, #args)

    local selected = table.remove(args, #args)
    if #selected == 0 then
        ctx.loc = nil
    else
        ctx.loc = get_loc_from_fc(fc, args[1])
    end

    if ctx.ui_cfg.preview then
        ui.preview(ctx, ctx.loc)
    end
end

return _M
