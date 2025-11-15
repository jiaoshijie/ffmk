local _M = {}
local config = require("ffmk.config")
local ff = require("ffmk.fzf")
local fmt = string.format
local utils = require("ffmk.utils")

_M.provider_ctx = {
    target_winid = nil,

    cfg = nil,
    win_cfg = nil,
    cb = nil,

    ff_bufnr = nil,
    ff_winid = nil,

    ff_preview_winid = nil,
    ff_preview_bufs = nil,  -- { "ffmk" = bufnr, "abs_filepath" = bufnr }
}

local gen_files_cmd = function(cfg)
    if type(cfg.cmd) ~= "string" then
        if vim.fn.executable('fd') == 1 then
            cfg.cmd = "fd --color=never --type f --type l"
        else
            cfg.cmd = "rg --color=never --files"
        end
    end

    local cmd = fmt("%s", cfg.cmd)

    cmd = cfg.follow and fmt("%s -L", cmd) or cmd
    cmd = cfg.hidden and fmt("%s --hidden", cmd) or cmd
    cmd = cfg.no_ignore and fmt("%s --no-ignore", cmd) or cmd

    -- TODO
    if cfg.filename_first then
        cmd = fmt("%s | conv 1", cmd)
    end

    return cmd
end

local files_wrapper = function()
    if type(_M.provider_ctx.cfg) ~= "table" then return end
    _M.provider_ctx.target_winid = vim.fn.win_getid()
    ff.run(_M.provider_ctx, gen_files_cmd(_M.provider_ctx.cfg))
end

_M.files = function(cfg)
    _M.provider_ctx.cfg = config.gen_provider_cfg(cfg or {}, "files")
    _M.provider_ctx.win_cfg = vim.deepcopy(config.cfg.win, true)
    _M.provider_ctx.cb = files_wrapper

    _M.provider_ctx.cb()
end

_M.release_ctx = function(exit, ff_main, ff_preview)
    local ctx = _M.provider_ctx
    if ff_main then
        utils.win_delete(ctx.ff_winid, true, true)
        ctx.ff_winid = nil
        ctx.ff_bufnr = nil
    end

    if ff_preview then
        utils.win_delete(ctx.ff_preview_winid, true, false)
        ctx.ff_preview_winid = nil
    end

    if exit then
        ctx.cfg = nil
        ctx.win_cfg = nil
        ctx.cb = nil
        -- NOTE: defer the deletion of the preview buf list a little bit
        -- then it will not block the ui
        local bufs = ctx.ff_preview_bufs
        ctx.ff_preview_bufs = nil
        if bufs then
            vim.defer_fn(function()
                for _, bufnr in pairs(bufs) do
                    utils.buf_delete(bufnr)
                end
            end, 1)
        end
    end
end

return _M
