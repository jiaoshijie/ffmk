local _M = {}
local fmt = string.format

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

-- --- @param path string
-- --- @return boolean is_syntax
-- --- @return boolean is_preview
-- _M.check_file_size = function(path)
--     local st = vim.uv.fs_stat(path)
--
--     return true, true
-- end

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

  vim.api.nvim_win_close(win_id, force)
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
