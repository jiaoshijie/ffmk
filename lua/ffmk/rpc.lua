local _M = {}
local rpc_fc = require('ffmk.config').rpc_fc
local rt = require('ffmk.runtime')

-- syntax limit is 512K
-- preview limit is 10M

local rpc_map = {
    [rpc_fc.quit] = rt.rpc_quit,
    [rpc_fc.query] = rt.rpc_query,
    [rpc_fc.files_enter] = rt.rpc_edit_or_send2qf,
    [rpc_fc.files_preview] = rt.rpc_files_preview,
}

_M.call = function(args)
    local func_code = table.remove(args, 1)
    rpc_map[func_code](func_code, args)
end

return _M
