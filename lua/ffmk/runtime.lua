local _M = {}
local fmt = string.format
local default_cfg = require('ffmk.config')
local ui = require('ffmk.ui')
local kit = require('ffmk.kit')
local ff = require('ffmk.fzf')
local action = require('ffmk.action')

--- @class Loc
--- @field path string?
--- @field row number?
--- @field col number?
--- @field helptag string?

--- @class QfLoc
--- @field filename string
--- @field lnum number
--- @field col number?
--- @field text string

-- { fzf, rg, fd }
local rt_env = {}

local ctx = {
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

--- @return boolean
local validate_env = function()
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
    if rt_env.rg == nil then
        local major, _, _ = kit.get_cmd_version('rg', '--version')
        rt_env.rg = major ~= nil and major >= 13
    end
    if rt_env.rg == false then
        kit.echo_err_msg("ripgrep version is below 13.0.0")
        return false
    end

    -- 5. if fd version not match, this will not fail, but will use rg instead
    if rt_env.fd == nil then
        local major, minor, _ = kit.get_cmd_version('fd', '--version')
        rt_env.fd = major ~= nil and (major > 8 or (major == 7 and minor >= 3))
    end

    return true
end

--- @param cfg table ctx.ui_cfg
local config_ui_cfg = function(cfg)
    ctx.ui_cfg = vim.tbl_extend('force', default_cfg.ui_cfg, cfg or {})
end

--- @param name string ctx.name
--- @param cfg table ctx.cmd_cfg
local config_cmd_cfg = function(name, cfg)
    ctx.name = name;
    ctx.cmd_cfg = vim.tbl_extend('force', default_cfg.cmd_cfg[name], cfg or {})
end

local set_target_winid = function()
    ctx.target_winid = vim.fn.win_getid()
end

--- @param cfg table { ui = {}, cmd = {} }
--- @return boolean
_M.setup = function(name, cfg)
    if not validate_env() then
        return false
    end
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
    kit.clear_highlighted_cursor()
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
        ctx.target_winid = nil
        ctx.name = nil
        ctx.ui_cfg = nil
        ctx.cmd_cfg = nil
        ctx.query = nil

        -- NOTE: defer the deletion of the preview buf list a little bit
        -- then it will not block the ui
        local bufs = ctx.preview_bufs
        ctx.preview_bufs = nil
        if bufs then
            vim.defer_fn(function()
                for _, bufnr in pairs(bufs) do
                    kit.buf_delete(bufnr)
                end
            end, 1)
        end

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
    cmd = cfg.smart_case and fmt("%s --smart-case", cmd) or cmd
    cmd = cfg.fixed_string and fmt("%s -F", cmd) or cmd
    cmd = cfg.whole_word and fmt("%s -w", cmd) or cmd

    -- extra options
    if type(cfg.extra_options) == "table" and #cfg.extra_options > 0 then
        cmd = fmt("%s %s", cmd, table.concat(cfg.extra_options, ' '))
    end

    cfg.query = vim.fn.shellescape(cfg.query, false)
    cmd = fmt([[%s %s | conv %d]], cmd, cfg.query, default_cfg.conv_fc.grep)

    return cmd
end

local set_keymaps = function(bufnr)
    vim.keymap.set('t', "<A-h>", function()
        action.toggle_hidden(ctx, _M)
    end, { buffer = bufnr })
    vim.keymap.set('t', "<A-i>", function()
        action.toggle_no_ignore(ctx, _M)
    end, { buffer = bufnr })
    vim.keymap.set('t', "<A-f>", function()
        action.toggle_follow(ctx, _M)
    end, { buffer = bufnr })
    vim.keymap.set('t', "<A-p>", function()
        action.toggle_preview(ctx, _M)
    end, { buffer = bufnr })
    vim.keymap.set('t', '<C-c>', function()
        action.quit(_M)
    end, { buffer = bufnr })
    vim.keymap.set('n', '<C-[>', function()
        action.quit(_M)
    end, { buffer = bufnr })
    vim.keymap.set('t', '<C-u>', function()
        action.preview_scroll_up(ctx)
    end, { buffer = bufnr })
    vim.keymap.set('t', '<C-d>', function()
        action.preview_scroll_down(ctx)
    end, { buffer = bufnr })
end

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
        search = ctx.cmd_cfg.query,
        search_title = ui.gen_grep_title(ctx.cmd_cfg),
    })
end

---------------------------------- rpc ---------------------------------------

--- @param fc number
--- @param arg string
--- @return Loc
local get_loc_from_fc = function(fc, arg)
    local path, row, col, helptag

    if fc == default_cfg.rpc_fc.files_enter
        or fc == default_cfg.rpc_fc.files_preview then
        path = ctx.cmd_cfg.filename_first
                and arg:gsub("([^\t]+)\t(.+)", "%2/%1") or arg
    elseif fc == default_cfg.rpc_fc.grep_enter
        or fc == default_cfg.rpc_fc.grep_send2qf
        or fc == default_cfg.rpc_fc.grep_preview then
        local b, e = string.find(arg, "\28")
        path = string.sub(arg, 1, b - 1)
        row, col, _ = string.match(string.sub(arg, e + 1), ":(%d+):(%d+):(.+)")
    else
        assert(nil, "unreachable!")
    end

    return {
        path = kit.abs_path(ctx.cmd_cfg.cwd, path),
        row = row and tonumber(row),
        col = col and tonumber(col) - 1,
        helptag = helptag,
    }
end

--- @param fc number
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
    else
        assert(nil, "unreachable!")
    end
    return qflist
end

--- @param fc number
--- @param args table
_M.rpc_quit = function(fc, args)
    local _, _ = fc, args
    _M.release(true, true, true)
end

--- @param fc number
--- @param args table
_M.rpc_query = function(fc, args)
    local _ = fc
    ctx.query = args[1]
end

--- @param fc number
--- @param args table
_M.rpc_edit_or_send2qf = function(fc, args)
    kit.goto_winid(ctx.target_winid)
    local selected = table.remove(args, #args)
    if #selected == 0 then
        action.quit(_M)
        return
    end

    if #args == 1 then
        kit.edit(get_loc_from_fc(fc, args[1]))
    elseif #args > 1 then
        vim.fn.setqflist(get_qfloc_from_fc(fc, args), 'r')
        vim.cmd('copen | cfirst')
    end
    action.quit(_M)
end

_M.rpc_preview = function(fc, args)
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
