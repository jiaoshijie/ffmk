local _M = {}
local fmt = string.format
local kit = require('ffmk.kit')
local default_cfg = require('ffmk.config')

-- TreeSitter Injection: https://github.com/ibhagwan/fzf-lua/issues/1485
-- Seems very cool, maybe add it later

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

--- @param cfg table runtime_ctx.cmd_cfg  grep
--- @return string
_M.gen_grep_title = function(cfg)
    local flag = ""

    flag = cfg.smart_case and flag .. 'S' or flag .. 's'
    flag = cfg.fixed_string and flag .. 'F' or flag
    flag = cfg.whole_word and flag .. 'w' or flag

    return #flag > 0 and fmt("Pattern(%s)", flag) or "Pattern"
end

--- @param cfg table runtime_ctx.cmd_cfg  gnu_global
--- @return string
_M.gen_gnu_global_title = function(cfg)
    local isfile = cfg.feat == default_cfg.gnu_global_feats.file_symbols
    if isfile then return "Path" end
    local flag = ""

    flag = cfg.ignore_case and flag .. 'I' or flag .. 's'
    flag = cfg.fixed_string and flag .. 'F' or flag

    return #flag > 0 and fmt("Pattern(%s)", flag) or "Pattern"
end

--- @param winid number
--- @param warn_win boolean enabled cursorline or not
local set_win_opts = function(winid, warn_win)
    if not warn_win then
        vim.api.nvim_set_option_value('cursorline', true, { win = winid })
        vim.api.nvim_set_option_value('cursorlineopt', "both", { win = winid })
        vim.api.nvim_set_option_value('number', true, { win = winid })
    end

    vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('spell', false, { win = winid })
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
    vim.api.nvim_set_option_value('colorcolumn', '0', { win = winid })
    vim.api.nvim_set_option_value('foldenable', false, { win = winid })
    vim.api.nvim_set_option_value('list', false, { win = winid })
    vim.api.nvim_set_option_value('scrolloff', 0, { win = winid })
    vim.api.nvim_set_option_value('winbar', "", { win = winid })
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
            vim.api.nvim_set_option_value('winblend', 0, { win = ctx.preview_winid })
        else
            vim.api.nvim_win_set_config(ctx.preview_winid, preview)
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
local update_preview_warn = function(ctx, bufnr, text)
    if bufnr ~= ctx.preview_bufs['ffmk'] then
        return
    end

    local ns = vim.api.nvim_create_namespace("ffmk_ui_preview_ns")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { text })
    vim.api.nvim_win_set_config(ctx.preview_winid, { title = "" })
    nvim_win_set_buf_noautocmd(ctx.preview_winid, bufnr)
    vim.hl.range(bufnr, ns, "FFMKWarnMsg", { 0, 0 }, { 0, -1 })
    vim.schedule(function()
        set_win_opts(ctx.preview_winid, true)
    end)
end

--- @param ctx table runtime_ctx
--- @param bufnr number
--- @param loc Loc
--- @param loaded_buf boolean
--- @param syntax boolean
local update_preview = function(ctx, bufnr, loc, loaded_buf, syntax)
    assert(loc ~= nil and loc.path ~= nil)
    if bufnr == ctx.preview_bufs['ffmk'] then
        return
    end

    local curbuf = vim.api.nvim_win_get_buf(ctx.preview_winid)
    if curbuf == bufnr then
        kit.set_win_cursor_pos(ctx.preview_winid, loc)
        kit.highlight_cursor(bufnr, loc)
        return
    end

    local filename = vim.fn.fnamemodify(loc.path, ':t')
    vim.api.nvim_win_set_config(ctx.preview_winid, { title = fmt(" %s ", filename), title_pos = "center" })
    nvim_win_set_buf_noautocmd(ctx.preview_winid, bufnr)

    if not loaded_buf then
        kit.read_file_async(loc.path, vim.schedule_wrap(function(data)
            local lines = vim.split(data, "[\r]?\n")

            -- if file ends in new line, don't write an empty string as the last
            -- line.
            if data:sub(#data, #data) == "\n" or data:sub(#data - 1, #data) == "\r\n" then
                table.remove(lines)
            end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            set_win_opts(ctx.preview_winid, false)
            kit.set_win_cursor_pos(ctx.preview_winid, loc)
            kit.highlight_cursor(bufnr, loc)


            if loc.ft then
                vim.api.nvim_set_option_value('filetype', loc.ft, { buf = bufnr })
                return
            end

            local ft = nil
            if syntax then ft = vim.filetype.match({ buf = bufnr, filename = filename }) end
            if ft then
                -- TODO: Do not know if there is a better to do the highlighting with no delay
                -- 1. If the filetype is set directly, there is sometimes a noticeable delay when scrolling through files. It may be acceptable, but I don't like it.
                -- 2. Using defer_fn reduces the delay a lot. However, another issue arises: when first opening Neovim and using ffmk with preview,
                --    sometimes the FZF terminal window rendering is weird. Since this only happens once per neovim session and doesn’t always occur, I prefer this one.
                --    When this happens, pressing <ESC> to return to Normal mode, then pressing A to go back to Insert mode will fix this issue.
                vim.defer_fn(function()
                    if vim.api.nvim_buf_is_valid(bufnr)
                        and vim.api.nvim_buf_is_loaded(bufnr) then
                        pcall(vim.api.nvim_set_option_value, 'filetype', ft, { buf = bufnr })
                    end
                end, 20)
                -- vim.api.nvim_set_option_value('filetype', ft, { buf = bufnr })
            end
        end))
    else
        vim.schedule(function()
            set_win_opts(ctx.preview_winid, false)
        end)
        kit.set_win_cursor_pos(ctx.preview_winid, loc)
        kit.highlight_cursor(bufnr, loc)
    end
end

--- @param ctx table runtime_ctx
--- @param loc Loc?
_M.preview = function(ctx, loc)
    if not loc or not loc.path or #loc.path == 0 then
        update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Nothing Selected ")
        return
    end

    local st = vim.uv.fs_stat(loc.path)
    if not st then
        update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Stat Failed ")
        return
    end

    if st.size == 0 then
        update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Empty File ")
        return
    end

    if kit.is_binary(loc.path) then
        update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Binary File ")
        return
    end

    local bufnr = vim.fn.bufnr(loc.path)
    local loaded = bufnr ~= -1

    if not loaded and st.size > 5 * 1024 * 1024 then  -- 5M
        update_preview_warn(ctx, ctx.preview_bufs['ffmk'], " Big File ")
        return
    end

    if not loaded then bufnr = ctx.preview_bufs[loc.path] end
    loaded = bufnr ~= nil

    if not loaded then
        bufnr = vim.api.nvim_create_buf(false, true)
        ctx.preview_bufs[loc.path] = bufnr
    end

    update_preview(ctx, bufnr, loc, loaded, st.size < 512 * 1024)  -- 512K
end

return _M
