# ffmk(fuzzy finder minimal kit)

It's a simple fzf wrapper for neovim.

## compile tools

`make help` for more information

## TODO

- [ ] lsp
  + `lsp_docmuent_symbols` filters only useful symbols (function definitions, methods, global variables) only for current buffer

## Examples

### ctags

```lua
vim.api.nvim_create_user_command("Ctags", function()
    require('ffmk').ctags({
        ui = { preview = true },
        cmd = { options = { "--kinds-c=-e" } },
    })
end, { nargs = 0 })
```

### gnu-global

```lua
vim.api.nvim_create_user_command("Gtagsd", function(opts)
    local query = opts.args
    if #query == 0 then
        query = vim.fn.expand("<cword>")
        if #query == 0 then
            print("WARNING: No query provided")
            return
        end
    end

    require('ffmk').gnu_global({
        ui = { preview = true },
        cmd = {
            query = query,
            feat = require('ffmk.config').gnu_global_feats.definition,
        },
    })
end, {
    nargs = '?',
    complete = function(lead, _, _)
        return vim.fn.systemlist("global -cd " .. lead)
    end
})

vim.api.nvim_create_user_command("Gtags", function(opts)
    local arg = opts.args
    local feats = require('ffmk.config').gnu_global_feats
    local feat = nil

    if arg == "f" then
        feat = feats.file_symbols
    elseif arg == "r" then
        feat = feats.reference
    elseif arg == "s" then
        feat = feats.other_symbols
    elseif arg == "g" then
        feat = feats.grep_symbols
    else
        print("WARNING: Invalid arg")
        return
    end

    require('ffmk').gnu_global({
        ui = { preview = true },
        cmd = {
            query = arg ~= "f" and vim.fn.expand("<cword>"),
            feat = feat,
        },
    })
end, {
    nargs = 1,
    complete = function(_, _, _)
        return { "r", "f", "g", "s" }
    end
})
```
