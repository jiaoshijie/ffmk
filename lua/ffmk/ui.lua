local _M = {}

local gen_win_layout = function(win_cfg)
    local round = math.ceil
    local max_col, max_line = vim.o.columns, vim.o.lines
    local is_small = false
    local preview = nil
    local frac = 1

    max_line = max_line - vim.o.cmdheight
    if vim.o.ls ~= 0 then max_line = max_line - 1 end
    if #vim.o.winbar ~= 0 then max_line = max_line - 1 end

    local w = math.floor(max_col * win_cfg.width)
    local h = math.floor(max_line * win_cfg.height)
    local c = math.floor((max_col - w) * win_cfg.col)
    local r = math.floor((max_line - h) * win_cfg.row)

    if win_cfg.preview then
        frac = 0.4
        is_small = (w * 0.6) < 70
    end

    local fzf = {
        width = is_small and w or round(w * frac),
        height = is_small and round(h * frac) or h,
        col = c,
        row = r,
    }

    if win_cfg.preview then
        preview = {
            width = is_small and w or w - fzf.width - 2,
            height = is_small and h - fzf.height - 2 or h,
            col = is_small and c or c + fzf.width + 2,
            row = is_small and r + fzf.height + 2 or r,
        }
    end

    return fzf, preview
end

_M.create = function(ctx)
    local fzf_win, preview_win = gen_win_layout(ctx.win_cfg)

    -- TODO: should check the winid is valid or not
    if not ctx.ff_winid then
        ctx.ff_bufnr = vim.api.nvim_create_buf(false, true)
        ctx.ff_winid = vim.api.nvim_open_win(ctx.ff_bufnr, true, {
            relative = "editor",
            col = fzf_win.col,
            row = fzf_win.row,
            width = fzf_win.width,
            height = fzf_win.height,
            style = "minimal",
            border = "rounded",
            title = " fzf ",
            title_pos = "center",
            noautocmd = true,
        })
        vim.keymap.set('t', "<A-h>", function()
            require('ffmk.action').toggle_search_option(false, true, false)
        end, { buffer = ctx.ff_bufnr })
        vim.keymap.set('t', "<A-i>", function()
            require('ffmk.action').toggle_search_option(false, false, true)
        end, { buffer = ctx.ff_bufnr })
        vim.keymap.set('t', "<A-f>", function()
            require('ffmk.action').toggle_search_option(true, false, false)
        end, { buffer = ctx.ff_bufnr })
        vim.keymap.set('t', "<A-p>", function()
            require('ffmk.action').toggle_preview()
        end, { buffer = ctx.ff_bufnr })
        vim.keymap.set('t', '<C-c>', function()
            require('ffmk.provider').release_ctx(true, true, true)
        end, { buffer = ctx.ff_bufnr })
        vim.keymap.set('n', '<C-[>', function()
            require('ffmk.provider').release_ctx(true, true, true)
        end, { buffer = ctx.ff_bufnr })
    else
        fzf_win.relative = "editor"
        vim.api.nvim_win_set_config(ctx.ff_winid, fzf_win)
        -- resize the window
    end

    -- TODO: should check the winid is valid or not
    if preview_win and not ctx.ff_preview_winid then
        ctx.ff_preview_bufs = ctx.ff_preview_bufs or {}
        local preview_bufnr = ctx.ff_preview_bufs["ffmk"]
        if not preview_bufnr then
            preview_bufnr = vim.api.nvim_create_buf(false, true)
            ctx.ff_preview_bufs["ffmk"] = preview_bufnr
        end
        ctx.ff_preview_winid = vim.api.nvim_open_win(preview_bufnr, false, {
            relative = "editor",
            col = preview_win.col,
            row = preview_win.row,
            width = preview_win.width,
            height = preview_win.height,
            style = "minimal",
            border = "rounded",
            title = " preview ",
            title_pos = "center",
            noautocmd = true,
        })
    end
end

return _M
