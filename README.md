# ffmk(fuzzy finder minimal kit)

It's a simple fzf wrapper for neovim.

## compile tools

- dump log: `CFLAGS="-DFFMK_DUMP_LOG" make -B`

### TODO

- [ ] tags(ctags, gnu-global) not only simple filter raw tags
  + `ctags` (function definitions, methods, global variables)
  + `gtags` gnu-global (function definitions, methods, global variables)
- [ ] lsp
  + `lsp_docmuent_symbols` filter only useful symbols (function definitions, methods, global variables) only for current buffer

## other repos'TODO

- [ ] `undotree` and `onlysearch` should not open when in command line window
- [ ] `undotree` make the cursor always in the middle of the undotree window
- [ ] `onlysearch` remove the Search virtual text from the ui
