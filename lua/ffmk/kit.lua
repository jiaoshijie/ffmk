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
    local obj = vim.system({cmd, ver_flag}, {
        text = true,
        clear_env = true,
    }):wait()
    if obj.code ~= 0 or obj.signal ~= 0
        or #obj.stderr > 0 then
        return nil, nil, nil
    end
    local major, minor, patch = obj.stdout:match("(%d+)%.(%d+)%.(%d+)\n")

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

    -- TODO: more robust

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

_M.read_file_async = function(path, cb)
  vim.uv.fs_open(path, "r", tonumber('644', 8), function(err_open, fd)
      if err_open then
          -- TODO: log
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

return _M
