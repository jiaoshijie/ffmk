# ffmk(fuzzy finder minimal kit)

It's a simple fzf wrapper for neovim.

## compile tools

`make help` for more information

## TODO

- [ ] `gnu-global` (function definitions, methods, global variables)
  + `-c` for command completion

### low priority

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
vim.api.nvim_create_user_command("Gtagsf", function()
    require('ffmk').gnu_global({
        ui = { preview = true },
        cmd = {
            feat = require('ffmk.config').gnu_global_feats.file_symbols
        },
    })
end, { nargs = 0 })
vim.api.nvim_create_user_command("Gtagsd", function()
    require('ffmk').gnu_global({
        ui = { preview = true },
        cmd = {
            query = vim.fn.expand("<cword>"),
            feat = require('ffmk.config').gnu_global_feats.definition,
        },
    })
end, { nargs = 0 })
vim.api.nvim_create_user_command("Gtagsr", function()
    require('ffmk').gnu_global({
        ui = { preview = true },
        cmd = {
            query = vim.fn.expand("<cword>"),
            feat = require('ffmk.config').gnu_global_feats.reference,
        },
    })
end, { nargs = 0 })
vim.api.nvim_create_user_command("Gtagsg", function()
    require('ffmk').gnu_global({
        ui = { preview = true },
        cmd = {
            query = vim.fn.expand("<cword>"),
            feat = require('ffmk.config').gnu_global_feats.grep_symbols,
        },
    })
end, { nargs = 0 })
vim.api.nvim_create_user_command("Gtagso", function()
    require('ffmk').gnu_global({
        ui = { preview = true },
        cmd = {
            query = vim.fn.expand("<cword>"),
            feat = require('ffmk.config').gnu_global_feats.other_symbols,
        },
    })
end, { nargs = 0 })
```
