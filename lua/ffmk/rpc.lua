local _M = {}
local rpc_fc = require('ffmk.config').rpc_fc
local rt = require('ffmk.runtime')

-- syntax limit is 512K
-- preview limit is 10M

local rpc_map = {
    [rpc_fc.files_enter] = rt.edit_or_send2qf,
    [rpc_fc.files_preview] = rt.files_preview,
}

_M.call = function(args)
    rt.set_query(table.remove(args, #args))
    local func_code = table.remove(args, 1)
    rpc_map[func_code](func_code, args)
end

return _M
