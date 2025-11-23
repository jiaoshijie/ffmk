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
_M.toggle_grep_whole_word = function(ctx, rt)
    ctx.cmd_cfg.whole_word = not ctx.cmd_cfg.whole_word
    rt.release(false, true, false)

    rt.run()
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_grep_fixed_string = function(ctx, rt)
    ctx.cmd_cfg.fixed_string = not ctx.cmd_cfg.fixed_string
    rt.release(false, true, false)

    rt.run()
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_grep_case = function(ctx, rt)
    ctx.cmd_cfg.smart_case = not ctx.cmd_cfg.smart_case
    rt.release(false, true, false)

    rt.run()
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_gnu_global_case = function(ctx, rt)
    ctx.cmd_cfg.ignore_case = not ctx.cmd_cfg.ignore_case
    rt.release(false, true, false)

    rt.run()
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.toggle_gnu_global_fixed_string = function(ctx, rt)
    ctx.cmd_cfg.fixed_string = not ctx.cmd_cfg.fixed_string
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

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.quit = function(ctx, rt)
    local _ = ctx
    rt.release(true, true, true)
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.preview_scroll_up = function(ctx, rt)
    local _ = rt
    kit.scroll(ctx.preview_winid, true)
end

--- @param ctx table runtime_ctx
--- @param rt table runtime_functions
_M.preview_scroll_down = function(ctx, rt)
    local _ = rt
    kit.scroll(ctx.preview_winid, false)
end

return _M
