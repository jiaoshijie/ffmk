local _M = {}

local fzf_cfg = {
    fzf_bin = "fzf",
    colors = {
        bg = nil,
        ["bg+"] = "#3c3836",
        border = "#8ec07c",
        fg = "#fbf1c7",
        ["fg+"] = "#fbf1c7",
        gutter = nil,
        header = "#928374",
        hl = "#fabd2f",
        ["hl+"] = "#fabd2f",
        info = "#504945",
        marker = "#fb4934",
        pointer = "#fabd2f",
        prompt = "#fb4934",
        query = "#fbf1c7:regular",
        scrollbar = "#83a598",
        separator = "#8ec07c",
        spinner = "#fabd2f",
    },
    opt = {
        ["--ansi"] = true,
        ["--border"] = "none",
        ["--cycle"] = true,
        ["--height"] = "100%",
        ["--highlight-line"] = true,
        ["--info"] = "inline-right",
        ["--layout"] = "default",
        ["--tabstop"] = "4",
    },
    files = {
        opt = {
            ["--no-multi"] = true,
            ["--scheme"] = "path",
            ["--tabstop"] = "1",
        },
    },
    grep = {
        opt = {
            ["--multi"] = true,
        }
    },
    helptags = {
        opt = {
            ["--no-multi"] = true,
            ["--delimiter"] = "[ ]",
            ["--tiebreak"] = "begin",
            ["--with-nth"] = "..-2"
        },
    },
}

_M.cfg = {
    ff = fzf_cfg,
    win = {
        preview = true,
        col = 0.50,
        row = 0.50,
        width = 0.90,
        height = 0.90,
    },
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

_M.setup = function(cfg)
    _M.cfg = vim.tbl_extend("force", _M.cfg, cfg)
end

_M.gen_provider_cfg = function(cfg, provider)
    local new_cfg = vim.deepcopy(_M.cfg[provider], true)
    new_cfg.provider_name = provider
    return vim.tbl_extend("force", new_cfg, cfg)
end

return _M
