local _M = {}
local rt = require('ffmk.runtime')

--- @param cfg table? { ui = {}, cmd = {} }
_M.files = function(cfg)
    if not rt.setup("files", cfg, { rg = true, fd = true }) then return end
    rt.run()
end

--- @param cfg table? { ui = {}, cmd = {} }
_M.grep = function(cfg)
    if not rt.setup("grep", cfg, { rg = true }) then return end
    rt.run()
end

--- @param cfg table? { ui = {}, cmd = {} }
_M.helptags = function(cfg)
    if not rt.setup("helptags", cfg, nil) then return end
    rt.run()
end

return _M
