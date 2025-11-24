local _M = {}
local fmt = string.format

--- @param msg string
_M.echo_err_msg = function(msg)
    vim.api.nvim_echo({ { fmt("ffmk: %s", msg) } }, true, { err = true })
end

--- @return number? major
--- @return number? minor
--- @return number? patch
_M.get_cmd_version = function(cmd, ver_flag)
    if vim.fn.executable(cmd) ~= 1 then
        return nil, nil, nil
    end
    local obj = vim.system({ cmd, ver_flag }, {
        text = true,
        clear_env = true,
    }):wait()
    if obj.code ~= 0 or obj.signal ~= 0
        or #obj.stderr > 0 then
        return nil, nil, nil
    end
    local major, minor, patch = obj.stdout:match("(%d+)%.(%d+)%.(%d+)")

    if not major or not minor or not patch then
        return nil, nil, nil
    end

    return tonumber(major), tonumber(minor), tonumber(patch)
end

--- @param path string
--- @return boolean
local lua_is_binary = function(path)
    local f, _ = io.open(path, "rb")
    if not f then
        return true
    end

    local chunk = f:read(4096)
    f:close()

    if chunk:find('\0') then
        return true
    end

    -- TODO(is_binary): more robust

    return false
end

--- @param path string
--- @return boolean
_M.is_binary = function(path)
    if vim.fn.executable('perl') ~= 1 then
        return lua_is_binary(path)
    end
    vim.fn.system({"perl", "-e", fmt([[exit(-B "%s")]], path:gsub('"', '\\"'))})
    return vim.v.shell_error ~= 0
end

--- @param bufnr number
_M.buf_delete = function(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr)
      or not vim.api.nvim_buf_is_loaded(bufnr) then
      return
  end

  -- Suppress the buffer deleted message for those with &report<2
  local start_report = vim.o.report
  vim.o.report = 2

  vim.api.nvim_buf_delete(bufnr, { force = true })

  vim.o.report = start_report
end

--- @param win_id number
--- @param force boolean see :h nvim_win_close
_M.win_delete = function(win_id, force)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  local save_ei = vim.o.eventignore
  vim.o.eventignore = "all"
  vim.api.nvim_win_close(win_id, force)
  vim.o.eventignore = save_ei
end

--- @param path string
--- @param cb fun(string)
_M.read_file_async = function(path, cb)
  vim.uv.fs_open(path, "r", tonumber('644', 8), function(err_open, fd)
      if err_open then
          _M.echo_err_msg(fmt("Open `%s` failed: %s", path, err_open))
          return
      end
      vim.uv.fs_fstat(fd, function(err_fstat, stat)
          assert(not err_fstat and stat, err_fstat)
          if stat.type ~= "file" then return cb("") end

          vim.uv.fs_read(fd, stat.size, 0, function(err_read, data)
              assert(not err_read, err_read)
              vim.uv.fs_close(fd, function(err_close)
                  assert(not err_close, err_close)
                  return cb(data)
              end)
          end)
      end)
  end)
end

--- @param winid number
--- @param up boolean  -- true: up,false: down
_M.scroll = function(winid, up)
    if not winid or not vim.api.nvim_win_is_valid(winid) then
        return
    end
    local cmd = up and "Hgk" or "Lgj"

    pcall(vim.api.nvim_win_call, winid, function()
        vim.cmd(fmt("norm! %s", cmd))
        local wi = vim.fn.getwininfo(winid)[1]
        vim.api.nvim_win_set_cursor(winid, { math.floor((wi.botline + wi.topline) / 2), 0 })
    end)
end


--- @param cwd string?
--- @param path string?
--- @return string?
_M.abs_path = function(cwd, path)
    if not path then return nil end
    if string.sub(path, 1, 1) ~= '/' then
        path = string.sub(path, 1, 2) == './' and string.sub(path, 3) or path
        path = vim.fn.expand(cwd or vim.fn.getcwd()) .. '/' .. path
    end

    return path
end

--- @param winid number
--- @param loc Loc
_M.set_win_cursor_pos = function(winid, loc)
    if loc.row then
        vim.api.nvim_win_set_cursor(winid, { loc.row, loc.col or 0, })
    elseif loc.helptag then
        if not winid then return end
        vim.api.nvim_win_call(winid, function()
            vim.api.nvim_win_set_cursor(winid, { 1,  0, })
            if vim.fn.search("\\V" .. loc.helptag.pattern, 'W') == 0 then
                _M.echo_err_msg(fmt("helptag `%s` not found", loc.helptag.pattern))
            end
        end)
    else
        return
    end
    vim.api.nvim_win_call(winid, function()
        vim.cmd("norm! zz")
    end)
end

local g_last_bufnr = nil
--- @param bufnr number
--- @param loc Loc
_M.highlight_cursor = function(bufnr, loc)
    local ns = vim.api.nvim_create_namespace("ffmk_ui_preview_cursor_ns")
    _M.clear_highlighted_cursor()
    g_last_bufnr = bufnr
    if loc.row and loc.col then
        vim.hl.range(bufnr, ns, "FFMKPreviewCursor", { loc.row - 1, loc.col },
                        { loc.row - 1, loc.col + 1 })
    else
        return
    end
end
_M.clear_highlighted_cursor = function(ns)
    if not ns then
        ns = vim.api.nvim_create_namespace("ffmk_ui_preview_cursor_ns")
    end

    if g_last_bufnr and vim.api.nvim_buf_is_valid(g_last_bufnr)
        and vim.api.nvim_buf_is_loaded(g_last_bufnr) then
        vim.api.nvim_buf_clear_namespace(g_last_bufnr, ns, 0, -1)
    end
end

--- @param loc Loc
_M.edit = function(loc)
    if not loc.path or #loc.path == 0 then
        _M.echo_err_msg("No path found")
        return
    end
    if not loc.helptag then
        vim.cmd('edit ' .. vim.fn.fnameescape(loc.path))
        _M.set_win_cursor_pos(0, loc)
    else
        local rtp = vim.fn.fnamemodify(loc.path, ":p:h:h")
        if vim.fn.stridx(vim.o.runtimepath, rtp) < 0 then
            vim.opt.runtimepath:append(rtp)
        end
        vim.schedule(function()
            vim.cmd('help ' .. vim.fn.fnameescape(loc.helptag.tag))
        end)
    end
end

--- @param prefer_winid number?
_M.goto_winid = function(prefer_winid)
    if prefer_winid and vim.api.nvim_win_is_valid(prefer_winid) then
        vim.fn.win_gotoid(prefer_winid)
    else
        -- NOTE: As the windows created by this plugin are all floating windows,
        -- there must be a valid normal window in the grid
        -- TODO(goto_winid): check `winfixbuf` option
        vim.fn.win_gotoid(vim.fn.win_getid(1))
    end
end

--- @param cmd string
--- @param cwd string?
--- @param winid number
--- @return boolean
_M.gnu_global_definition = function(cmd, cwd, winid)
    local res = vim.fn.systemlist(vim.split(cmd, '|')[1])
    if vim.v.shell_error ~= 0 or #res ~= 1 then
        return false
    end
    local path, lnum, _ = res[1]:match("(.+)\t(%d+)\t(.+)")

    if not path or not lnum then return false end

    _M.goto_winid(winid)
    _M.edit({
        path = _M.abs_path(cwd, path),
        row = tonumber(lnum),
    })

    return true
end

return _M
