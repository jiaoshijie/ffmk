local _M = {}

local fmt = string.format

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

_M.is_binary = function(path)
    if vim.fn.executable('perl') ~= 1 then
        return lua_is_binary(path)
    end
    vim.fn.system({"perl", "-e", fmt([[exit(-B "%s")]], path:gsub('"', '\\"'))})
    return vim.v.shell_error ~= 0
end

--- For deleting onlysearch buffer, used by win_delete()
--- @param bufnr number
_M.buf_delete = function(bufnr)
  if bufnr == nil then
    return
  end

  -- Suppress the buffer deleted message for those with &report<2
  local start_report = vim.o.report
  if start_report < 2 then
    vim.o.report = 2
  end

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if start_report < 2 then
    vim.o.report = start_report
  end
end

--- For closing onlysearch window and deleting the buffer, used by coll:close()
--- @param win_id number
--- @param force boolean see :h nvim_win_close
--- @param bdelete boolean delete the buffer or not
_M.win_delete = function(win_id, force, bdelete)
  if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(win_id)
  if bdelete then
    _M.buf_delete(bufnr)
  end

  if not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  vim.api.nvim_win_close(win_id, force)
end

return _M
