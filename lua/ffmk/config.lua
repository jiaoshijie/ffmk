local _M = {}
local fmt = string.format

_M.conv_fc = {
    files      = 0,
    grep       = 1,
    helptags   = 2,
    ctags      = 3,
    gnu_global = 4,
}

_M.rpc_fc = {
    quit               = 0,
    query              = 1,
    files_enter        = 2,
    files_preview      = 3,
    grep_enter         = 4,
    grep_send2qf       = 5,
    grep_preview       = 6,
    helptags_enter     = 7,
    helptags_preview   = 8,
    ctags_enter        = 9,
    ctags_send2qf      = 10,
    ctags_preview      = 11,
    gnu_global_enter   = 12,
    gnu_global_send2qf = 13,
    gnu_global_preview = 14,
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
        hl        = "reverse:-1",
        ["hl+"]   = "reverse:-1",
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
        "ctrl-d:ignore,ctrl-g:ignore,ctrl-q:ignore,ctrl-z:ignore",   -- disable some default keymaps
        "alt-a:toggle-all,alt-g:first,alt-G:last,ctrl-l:clear-screen+clear-multi",
        fmt("esc:execute-silent(rpc_client %d)", _M.rpc_fc.quit),
        fmt("change:execute-silent(rpc_client %d {q})", _M.rpc_fc.query),
    },
    preview = "--preview-window 'hidden'",
    files = {
        opt = {
            ["--no-multi"] = true,
            ["--scheme"]   = "path",
            ["--tabstop"]  = "1",
        },
        bind = {
            fmt("enter:execute-silent(rpc_client %d {} {n})", _M.rpc_fc.files_enter),
            fmt("focus:execute-silent(rpc_client %d {} {n})", _M.rpc_fc.files_preview),
        },
    },
    grep = {
        opt = {
            ["--multi"] = true,
        },
        bind = {
            fmt("enter:execute-silent(rpc_client %d {} {n})", _M.rpc_fc.grep_enter),
            fmt("alt-q:execute-silent(rpc_client %d {+} {n})", _M.rpc_fc.grep_send2qf),
            fmt("focus:execute-silent(rpc_client %d {} {n})", _M.rpc_fc.grep_preview),
        },
    },
    helptags = {
        opt = {
            ["--no-multi"] = true,
            ["--tiebreak"] = "begin",
            ["--delimiter"] = "\28",
            ["--with-nth"] = "1,4",
            ["--nth"] = "1",
        },
        bind = {
            fmt("enter:execute-silent(rpc_client %d {1..3} {n})", _M.rpc_fc.helptags_enter),
            fmt("focus:execute-silent(rpc_client %d {1..3} {n})", _M.rpc_fc.helptags_preview),
        },
    },
    ctags = {
        opt = {
            ["--multi"] = true,
            ["--no-sort"] = true,
            ["--delimiter"] = "\28",
            ["--with-nth"] = "2",
        },
        bind = {
            fmt("enter:execute-silent(rpc_client %d {1} {n})", _M.rpc_fc.ctags_enter),
            fmt("alt-q:execute-silent(rpc_client %d {+} {n})", _M.rpc_fc.ctags_send2qf),
            fmt("focus:execute-silent(rpc_client %d {1} {n})", _M.rpc_fc.ctags_preview),
        },
    },
    gnu_global = {
        opt = {
            ["--multi"] = true,
        },
        bind = {
            fmt("enter:execute-silent(rpc_client %d {} {n})", _M.rpc_fc.gnu_global_enter),
            fmt("alt-q:execute-silent(rpc_client %d {+} {n})", _M.rpc_fc.gnu_global_send2qf),
            fmt("focus:execute-silent(rpc_client %d {} {n})", _M.rpc_fc.gnu_global_preview),
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

_M.keymaps_cfg = {
    global = {
        ["n"] = {
            ["<C-[>"] = "quit",
        },
        ["t"] = {
            ["<C-c>"] = "quit",
            ["<C-u>"] = "preview_scroll_up",
            ["<C-d>"] = "preview_scroll_down",
            ["<A-p>"] = "toggle_preview",
        },
    },
    files = {
        ["t"] = {
            ["<A-h>"] = "toggle_hidden",
            ["<A-i>"] = "toggle_no_ignore",
            ["<A-f>"] = "toggle_follow",
        },
    },
    grep = {
        ["t"] = {
            ["<A-h>"] = "toggle_hidden",
            ["<A-i>"] = "toggle_no_ignore",
            ["<A-f>"] = "toggle_follow",
        },
    },
}

_M.cmd_cfg = {
    files = {
        prompt = "Files❯ ",
        cmd = nil,
        cwd = nil,
        filename_first = true,
        -- options
        follow = false,
        hidden = false,
        no_ignore = false,
    },
    grep = {
        prompt = "Grep❯ ",
        query = nil,
        cwd = nil,
        -- commen options  -- config switched using keymap
        follow = false,  -- maybe need --no-messages
        hidden = false,
        no_ignore = false,
        -- options
        whole_word = false,
        fixed_string = false,
        smart_case = true,
        -- extra options
        extra_options = nil,  -- should be a table
    },
    helptags = {
        prompt = "Helptags❯ ",
    },
    ctags = {
        prompt = "Ctags❯ ",
        path = nil,  -- an absolute path or nil(the current file)
        options = nil, -- should be a table
    },
    gnu_global = {
        prompt = "GnuGlobal❯ ",
        query = nil,
        options = nil, -- should be a table
    },
}

--- @param cfg table  { ui = {}, cmd = { files = {} } }
_M.setup = function(cfg)
    _M.ui_cfg = vim.tbl_extend('force', _M.ui_cfg, cfg.ui or {})
    _M.cmd_cfg = vim.tbl_extend('force', _M.cmd_cfg, cfg.cmd or {})
end

return _M
