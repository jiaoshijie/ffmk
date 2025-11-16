local _M = {}
local fmt = string.format

_M.conv_fc = {
    files    = 1,
    grep     = 2,
    helptags = 3,
}

_M.rpc_fc = {
    files_enter      = 1,
    files_preview    = 2,
    grep_enter       = 3,
    grep_send2qf     = 4,
    grep_send2ll     = 5,
    grep_preview     = 6,
    helptags_enter   = 7,
    helptags_preview = 8,
}

_M.fzf_cfg = {
    bin = "fzf",
    colors = {
        bg        = nil,
        ["bg+"]   = "#3c3836",
        border    = "#8ec07c",
        fg        = "#fbf1c7",
        ["fg+"]   = "#fbf1c7",
        gutter    = nil,
        header    = "#928374",
        hl        = "#fabd2f",
        ["hl+"]   = "#fabd2f",
        info      = "#504945",
        marker    = "#fb4934",
        pointer   = "#fabd2f",
        prompt    = "#fb4934",
        query     = "#fbf1c7:regular",
        scrollbar = "#83a598",
        separator = "#8ec07c",
        spinner   = "#fabd2f",
    },
    opt = {
        ["--ansi"]           = true,
        ["--border"]         = "none",
        ["--cycle"]          = true,
        ["--height"]         = "100%",
        ["--highlight-line"] = true,
        ["--info"]           = "inline-right",
        ["--layout"]         = "default",
        ["--tabstop"]        = "4",
    },
    bind = {
        "alt-a:toggle-all,alt-g:first,alt-G:last",
    },
    preview = "--preview-window 'hidden'",
    files = {
        opt = {
            ["--no-multi"] = true,
            ["--scheme"]   = "path",
            ["--tabstop"]  = "1",
        },
        bind = {
            fmt("enter:execute-silent(rpc_client %d {} {n} {q})", _M.rpc_fc.files_enter),
            fmt("focus:execute-silent(rpc_client %d {} {n} {q})", _M.rpc_fc.files_preview),
        },
    },
}

_M.ui_cfg = {
    preview = false,
    col     = 0.50,
    row     = 0.50,
    width   = 0.90,
    height  = 0.90,
}

_M.cmd_cfg = {
    files = {
        cmd = nil,
        cwd = nil,
        follow = false,
        hidden = false,
        no_ignore = false,
        filename_first = true,
        prompt = "Files❯ "
    },
}

--- @param cfg table  { ui = {}, cmd = { files = {} } }
_M.setup = function(cfg)
    _M.ui_cfg = vim.tbl_extend('force', _M.ui_cfg, cfg.ui or {})
    _M.cmd_cfg = vim.tbl_extend('force', _M.cmd_cfg, cfg.cmd or {})
end

return _M
