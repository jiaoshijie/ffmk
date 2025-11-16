local _M = {}
local fmt = string.format
local default_cfg = require('ffmk.config')
local ui = require('ffmk.ui')
local kit = require('ffmk.kit')
local ff = require('ffmk.fzf')
local action = require('ffmk.action')

local ctx = {
    target_winid = nil,
    query = nil,
    preview_path = nil,

    name = nil,
    ui_cfg = nil,
    cmd_cfg = nil,

    bufnr = nil,
    preview_bufs = nil,  -- { "ffmk" = bufnr, "abs_path" = bufnr }

    winid = nil,
    preview_winid = nil,
}

local rt_func_map = {}

--- @param cfg table ctx.ui_cfg
_M.config_ui_cfg = function(cfg)
    ctx.ui_cfg = vim.tbl_extend('force', default_cfg.ui_cfg, cfg or {})
end

--- @param name string ctx.name
--- @param cfg table ctx.cmd_cfg
_M.config_cmd_cfg = function(name, cfg)
    ctx.name = name;
    ctx.cmd_cfg = vim.tbl_extend('force', default_cfg.cmd_cfg[name], cfg or {})
end

_M.set_target_winid = function()
    ctx.target_winid = vim.fn.win_getid()
end

--- @param query string
_M.set_query = function(query)
    ctx.query = query
end

_M.run = function()
    assert(type(rt_func_map[ctx.name]) == "function", "Provider function not found")
    rt_func_map[ctx.name]()
end

_M.release = function(exit, main, preview)
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
        ctx.preview_path = nil

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
        if vim.fn.executable('fd') == 1 then
            cfg.cmd = "fd --color=never --type f --type l --exclude '.git'"
        else
            cfg.cmd = "rg --color=never --files -g '!.git'"
        end
    end

    local cmd = fmt("%s", cfg.cmd)

    cmd = cfg.follow and fmt("%s -L", cmd) or cmd
    cmd = cfg.hidden and fmt("%s --hidden", cmd) or cmd
    cmd = cfg.no_ignore and fmt("%s --no-ignore", cmd) or cmd

    if cfg.filename_first then
        cmd = fmt("%s | conv %d", cmd, default_cfg.conv_fc.files)
    end

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
end

rt_func_map.files = function()
    -- 1. create bufers
    if not ctx.bufnr or not vim.api.nvim_buf_is_valid(ctx.bufnr) then
        ctx.bufnr = vim.api.nvim_create_buf(false, true)
        set_keymaps(ctx.bufnr)
    end
    ctx.preview_bufs = ctx.preview_bufs or {}
    if not ctx.preview_bufs["ffmk"]
        or not vim.api.nvim_buf_is_valid(ctx.preview_bufs["ffmk"]) then
        ctx.preview_bufs["ffmk"] = vim.api.nvim_create_buf(false, true)
    end
    -- 2. create ui
    ui.render(ctx)
    -- 3. run fuzzy finder
    ff.run(ctx.name, ctx.cmd_cfg.cwd, gen_files_cmd(ctx.cmd_cfg), ctx.cmd_cfg.prompt)
end

---------------------------------- rpc ---------------------------------------

--- @param fc number
--- @param path string
--- @return string
local gen_path_from_fc = function(fc, path)
    if fc == default_cfg.rpc_fc.files_enter
        or fc == default_cfg.rpc_fc.files_preview then
        path = ctx.cmd_cfg.filename_first
                and path:gsub("([^\t]+)\t(.+)", "%2/%1") or path
    else
        assert(nil, "unreachable!")
    end

    return path
end

--- @param fc number
--- @param path string
--- @return string
local gen_abs_path = function(fc, path)
    -- 1. remove the ansi escape color code, seems the fzf will strip it for me
    -- path = path:gsub("\27%[[0-9;]*m", "")

    -- 2. get the real path according to the function code
    path = gen_path_from_fc(fc, path)
    if string.sub(path, 1, 1) ~= '/' then
        path = string.sub(path, 1, 2) == './' and string.sub(path, 3) or path
        path = vim.fn.expand(ctx.cmd_cfg.cwd or vim.fn.getcwd()) .. '/' .. path
    end

    return path
end

--- @param fc number
--- @param args table
_M.edit_or_send2qf = function(fc, args)
    vim.fn.win_gotoid(ctx.target_winid)
    -- TODO: nothing selected case

    vim.cmd('edit ' .. vim.fn.fnameescape(gen_abs_path(fc, args[1])))
    action.quit(_M)
end

_M.files_preview = function(fc, args)
    local selected = table.remove(args, #args)
    if #selected == 0 then
        ctx.preview_path = nil
        ui.update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Nothing Selected ")
        return
    end

    local abs_path = gen_abs_path(fc, args[1])
    ctx.preview_path = abs_path

    if ctx.ui_cfg.preview then
        ui.preview(ctx, abs_path)
    end
end

return _M
