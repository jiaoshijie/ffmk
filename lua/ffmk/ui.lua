local _M = {}
local fmt = string.format
local kit = require('ffmk.kit')

local main_border = {
    { "╭", "FFMKBorder" },
    { "─", "FFMKBorder" },
    { "╮", "FFMKBorder" },
    { "│", "FFMKBorder" },
    { "╯", "FFMKBorder" },
    { "─", "FFMKBorder" },
    { "╰", "FFMKBorder" },
    { "│", "FFMKBorder" },
}

local preview_border = {
    { "╭", "FFMKPreviewBorder" },
    { "─", "FFMKPreviewBorder" },
    { "╮", "FFMKPreviewBorder" },
    { "│", "FFMKPreviewBorder" },
    { "╯", "FFMKPreviewBorder" },
    { "─", "FFMKPreviewBorder" },
    { "╰", "FFMKPreviewBorder" },
    { "│", "FFMKPreviewBorder" },
}

--- @param cfg table runtime_ctx.ui_cfg
--- @return table main  { relative = , width = , height = , col = , row =  }
--- @return table? preview
local gen_win_layout = function(cfg)
    local round = math.ceil
    local max_col, max_line = vim.o.columns, vim.o.lines
    local is_small = false
    local preview = nil
    local frac = 1

    max_line = max_line - vim.o.cmdheight
    if vim.o.ls ~= 0 then max_line = max_line - 1 end
    if #vim.o.winbar ~= 0 then max_line = max_line - 1 end

    local w = math.floor(max_col * cfg.width)
    local h = math.floor(max_line * cfg.height)
    local c = math.floor((max_col - w) * cfg.col)
    local r = math.floor((max_line - h) * cfg.row)

    if cfg.preview then
        frac = 0.4
        is_small = (w * 0.6) < 70
    end

    local main = {
        relative = "editor",
        width = is_small and w or round(w * frac),
        height = is_small and round(h * frac) or h,
        col = c,
        row = r,
    }

    if cfg.preview then
        preview = {
            relative = "editor",
            width = is_small and w or w - main.width - 2,
            height = is_small and h - main.height - 2 or h,
            col = is_small and c or c + main.width + 2,
            row = is_small and r + main.height + 2 or r,
        }
    end

    return main, preview
end

--- @param name string runtime_ctx.name
--- @param cfg table runtime_ctx.cmd_cfg
--- @return table { { "title", "hl" }, ... }
local gen_title = function(name, cfg)
    local title = { { fmt(" %s ", name) , "FFMKNormal" } }

    if cfg.hidden then
        table.insert(title, { " h ", "FFMKTitleFlags" })
    end

    if cfg.no_ignore then
        table.insert(title, { " i ", "FFMKTitleFlags" })
    end

    if cfg.follow then
        table.insert(title, { " f ", "FFMKTitleFlags" })
    end

    return title
end

--- @param ctx table runtime_ctx
_M.render = function(ctx)
    local main, preview = gen_win_layout(ctx.ui_cfg)

    if not ctx.winid or not vim.api.nvim_win_is_valid(ctx.winid) then
        assert(ctx.bufnr ~= nil, "ctx.bufnr must be created before calling this function")
        ctx.winid = vim.api.nvim_open_win(ctx.bufnr, true, {
            relative = main.relative,
            col = main.col,
            row = main.row,
            width = main.width,
            height = main.height,
            style = "minimal",
            noautocmd = true,
            border = main_border,
            title = gen_title(ctx.name, ctx.cmd_cfg),
            title_pos = "center",
        })
        vim.api.nvim_set_option_value('winblend', 0, { win = ctx.winid })
    else
        -- resize the window
        vim.api.nvim_win_set_config(ctx.winid, main)
    end

    if preview then
        if not ctx.preview_winid
            or not vim.api.nvim_win_is_valid(ctx.preview_winid) then
            assert(ctx.preview_bufs['ffmk'] ~= nil,
                "ctx.preview_bufs.ffmk must be created before calling this function")
            ctx.preview_winid = vim.api.nvim_open_win(ctx.preview_bufs['ffmk'], false, {
                relative = preview.relative,
                col = preview.col,
                row = preview.row,
                width = preview.width,
                height = preview.height,
                style = "minimal",
                noautocmd = true,
                border = preview_border,
            })
            vim.api.nvim_set_option_value('wrap', false, { win = ctx.preview_winid })
            vim.api.nvim_set_option_value('cursorline', true, { win = ctx.preview_winid })
            vim.api.nvim_set_option_value('wrap', false, { win = ctx.preview_winid })
            vim.api.nvim_set_option_value('spell', false, { win = ctx.preview_winid })
            vim.api.nvim_set_option_value('signcolumn', 'no', { win = ctx.preview_winid })
            vim.api.nvim_set_option_value('colorcolumn', '0', { win = ctx.preview_winid })
            vim.api.nvim_set_option_value('foldenable', false, { win = ctx.preview_winid })
            vim.api.nvim_set_option_value('winblend', 0, { win = ctx.preview_winid })
        else
            vim.api.nvim_win_set_config(ctx.winid, main)
        end
    end
end

local nvim_win_set_buf_noautocmd = function(winid, bufnr)
  local save_ei = vim.o.eventignore
  vim.o.eventignore = "all"
  vim.api.nvim_win_set_buf(winid, bufnr)
  vim.o.eventignore = save_ei
end

--- @param ctx table runtime_ctx
--- @param bufnr number
--- @param text string
_M.update_preview_warn = function(ctx, bufnr, text)
    if bufnr ~= ctx.preview_bufs['ffmk'] then
        return
    end

    local ns = vim.api.nvim_create_namespace("ffmk_ui_preview_ns")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { text })
    vim.api.nvim_win_set_config(ctx.preview_winid, { title = "" })
    nvim_win_set_buf_noautocmd(ctx.preview_winid, bufnr)
    vim.schedule(function()
        vim.hl.range(bufnr, ns, "FFMKWarnMsg", { 0, 0 }, { 0, -1 })
    end)
end

--- @param ctx table runtime_ctx
--- @param bufnr number
--- @param path string
--- @param loaded_buf boolean
--- @param syntax boolean
_M.update_preview = function(ctx, bufnr, path, loaded_buf, syntax)
    if bufnr == ctx.preview_bufs['ffmk'] then
        return
    end

    local curbuf = vim.api.nvim_win_get_buf(ctx.preview_winid)
    if curbuf == bufnr then return end

    local title = vim.fn.fnamemodify(path, ':t')
    vim.api.nvim_win_set_config(ctx.preview_winid, { title = fmt(" %s ", title), title_pos = "center" })
    nvim_win_set_buf_noautocmd(ctx.preview_winid, bufnr)

    if not loaded_buf then
        kit.read_file_async(path, vim.schedule_wrap(function(data)
            local lines = vim.split(data, "[\r]?\n")

            -- if file ends in new line, don't write an empty string as the last
            -- line.
            if data:sub(#data, #data) == "\n" or data:sub(#data - 1, #data) == "\r\n" then
                table.remove(lines)
            end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            vim.api.nvim_set_option_value('number', true, { win = ctx.preview_winid })

            local ft = nil
            if syntax then ft = vim.filetype.match({ buf = bufnr, filename = path }) end
            if ft then
                vim.defer_fn(function()
                    if vim.api.nvim_buf_is_valid(bufnr)
                        and vim.api.nvim_buf_is_loaded(bufnr) then
                        pcall(vim.api.nvim_set_option_value, 'filetype', ft, { buf = bufnr })
                    end
                end, 10)
            end
        end))
    else
        vim.schedule(function()
            vim.api.nvim_set_option_value('number', true, { win = ctx.preview_winid })
        end)
    end
end

_M.preview = function(ctx, abs_path)
    if not abs_path or #abs_path == 0 then
        return
    end

    if kit.is_binary(abs_path) then
        _M.update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Binary File ")
        return
    end

    local st = vim.uv.fs_stat(abs_path)
    if not st then
        _M.update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Stat Failed ")
        return
    end

    if st.size > 5 * 1024 * 1024 then  -- 5M
        _M.update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Big File ")
        return
    end

    local bufnr, loaded = vim.fn.bufnr(abs_path), true
    if bufnr == -1 then bufnr = ctx.preview_bufs[abs_path] end

    if not bufnr then
        loaded = false
        bufnr = vim.api.nvim_create_buf(false, true)
        ctx.preview_bufs[abs_path] = bufnr
    end

    _M.update_preview(ctx, bufnr, abs_path, loaded, st.size < 512 * 1024)  -- 512K
end

return _M
