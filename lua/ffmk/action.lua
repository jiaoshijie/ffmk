local _M = {}
local kit = require("ffmk.kit")

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_hidden = function(ctx, rt)
    ctx.cmd_cfg.hidden = not ctx.cmd_cfg.hidden
    rt.release(false, true, false)

    rt.run()
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_no_ignore = function(ctx, rt)
    ctx.cmd_cfg.no_ignore = not ctx.cmd_cfg.no_ignore
    rt.release(false, true, false)

    rt.run()
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_follow = function(ctx, rt)
    ctx.cmd_cfg.follow = not ctx.cmd_cfg.follow
    rt.release(false, true, false)

    rt.run()
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_preview = function(ctx, rt)
    ctx.ui_cfg.preview = not ctx.ui_cfg.preview
    vim.schedule(function()
        rt.release(false, false, true)
        require("ffmk.ui").render(ctx)
        if ctx.ui_cfg.preview then
            require("ffmk.ui").preview(ctx, ctx.loc)
        end
    end)
end

--- @param rt table runtime_functions
_M.quit = function(rt)
    rt.release(true, true, true)
end

--- @param ctx table runtime_ctx
_M.preview_scroll_up = function(ctx)
    kit.scroll(ctx.preview_winid, true)
end

--- @param ctx table runtime_ctx
_M.preview_scroll_down = function(ctx)
    kit.scroll(ctx.preview_winid, false)
end

return _M
