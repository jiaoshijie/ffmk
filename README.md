# ffmk(fuzzy finder minimal kit)

It's a simple fzf wrapper for neovim.

## compile tools

`make help` for more information

## TODO

- [ ] `gnu-global` (function definitions, methods, global variables)

### low priority

- [ ] lsp
  + `lsp_docmuent_symbols` filter only useful symbols (function definitions, methods, global variables) only for current buffer

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
