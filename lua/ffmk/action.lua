local _M = {}
local ctx = require('ffmk.provider').provider_ctx

-- syntax limit is 512K
-- preview limit is 10M

local gen_path_from_fc = function(func_code, path)
    if func_code == 1 or func_code == 2 then
        path = ctx.cfg.filename_first and path:gsub("([^\t]+)\t(.+)", "%2/%1") or path
    else
        assert(nil, "unreachable!")
    end

    return path
end

local gen_abs_path = function(func_code, path)
    local abs_path = nil
    -- 1. remove the ansi escape color code, seems the fzf will strip it for me
    -- path = path:gsub("\27%[[0-9;]*m", "")

    -- 2. get the real path according to the function code
    path = gen_path_from_fc(func_code, path)
    if string.sub(path, 1, 1) == '/' then
        abs_path = path
    else
        path = string.sub(path, 1, 2) == './' and string.sub(path, 3) or path
        abs_path = vim.fn.expand(ctx.cfg.cwd or vim.fn.getcwd()) .. '/' .. path
    end

    return abs_path
end

local edit_or_send2qf = function(func_code, args)
    vim.fn.win_gotoid(ctx.target_winid)
    vim.cmd('edit ' .. vim.fn.fnameescape(gen_abs_path(func_code, args[1])))
    require('ffmk.provider').release_ctx(true, true, true)
end

local files_preview = function(func_code, args)
    if not ctx.win_cfg.preview then
        return
    end
    local seleted = args[3]
    if #seleted == 0 then
        vim.api.nvim_win_set_buf(ctx.ff_preview_winid, ctx.ff_preview_bufs['ffmk'])
        return
    end

    local abs_path = gen_abs_path(func_code, args[1])
    -- TODO: check the abs_path exist or not
    local bufnr = ctx.ff_preview_bufs[abs_path]
    if bufnr == nil then
        bufnr = vim.api.nvim_create_buf(false, true)
        ctx.ff_preview_bufs[abs_path] = bufnr
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(abs_path))
        local ft = vim.filetype.match({ buf = bufnr, filename = abs_path })
        if ft then
            -- NOTE: the schedule function is important, otherwise the neovim rendering is weird at the first time
            vim.schedule(function()
                vim.api.nvim_set_option_value('filetype', ft, { buf = bufnr })
            end)
        end
    end
    vim.api.nvim_win_set_buf(ctx.ff_preview_winid, bufnr)
end

local action_map = {
    [1] = edit_or_send2qf,
    [2] = files_preview,
}

-- TODO: need a way to get the correct winid
_M.action = function(args)
    local func_code = table.remove(args, 1)
    action_map[func_code](func_code, args)
end

_M.toggle_search_option = function(follow, hidden, no_ignore)
    if follow then
        ctx.cfg.follow = not ctx.cfg.follow
    end
    if hidden then
        ctx.cfg.hidden = not ctx.cfg.hidden
    end
    if no_ignore then
        ctx.cfg.no_ignore = not ctx.cfg.no_ignore
    end
    require('ffmk.provider').release_ctx(false, true, false)

    ctx.cb()
end

_M.toggle_preview = function()
    ctx.win_cfg.preview = not ctx.win_cfg.preview
    require('ffmk.provider').release_ctx(false, false, true)
    -- reset window size
    require("ffmk.ui").create(ctx)
end

return _M
