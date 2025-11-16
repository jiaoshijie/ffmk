local _M = {}
local rt = require('ffmk.runtime')

--- @param cfg table { ui = {}, cmd = {} }
_M.files = function(cfg)
    rt.set_target_winid()
    rt.config_ui_cfg(cfg and cfg.ui)
    rt.config_cmd_cfg("files", cfg and cfg.cmd)

    rt.run()
end

return _M
