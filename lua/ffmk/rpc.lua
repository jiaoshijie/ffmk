local _M = {}
local rpc_fc = require('ffmk.config').rpc_fc
local rt = require('ffmk.runtime')

local rpc_map = {
    [rpc_fc.quit] = rt.rpc_quit,
    [rpc_fc.query] = rt.rpc_query,
    [rpc_fc.files_enter] = rt.rpc_edit_or_send2qf,
    [rpc_fc.files_preview] = rt.rpc_preview,
    [rpc_fc.grep_enter] = rt.rpc_edit_or_send2qf,
    [rpc_fc.grep_preview] = rt.rpc_preview,
}

_M.call = function(args)
    local func_code = table.remove(args, 1)
    rpc_map[func_code](func_code, args)
end

return _M
