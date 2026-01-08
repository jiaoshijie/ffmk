local _M = {}

--- @param cfg table? { ui = {}, cmd = {} }
_M.files = function(cfg)
    local rt = require('ffmk.runtime')
    if not rt.setup("files", cfg, { rg = true, fd = true }) then return end
    rt.run()
end

--- @param cfg table? { ui = {}, cmd = {} }
_M.grep = function(cfg)
    local rt = require('ffmk.runtime')
    if not rt.setup("grep", cfg, { rg = true }) then return end
    rt.run()
end

--- @param cfg table? { ui = {}, cmd = {} }
_M.helptags = function(cfg)
    local rt = require('ffmk.runtime')
    if not rt.setup("helptags", cfg, nil) then return end
    rt.run()
end

--- @param cfg table? { ui = {}, cmd = {} }
_M.ctags = function(cfg)
    local rt = require('ffmk.runtime')
    if not rt.setup("ctags", cfg, { ctags = true }) then return end
    rt.run()
end

--- @param cfg table? { ui = {}, cmd = {} }
_M.gnu_global = function(cfg)
    local rt = require('ffmk.runtime')
    if not rt.setup("gnu_global", cfg, { gnu_global = true }) then return end
    rt.run()
end

return _M
