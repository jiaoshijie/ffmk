# ffmk(fuzzy finder minimal kit)

- [x] check fzf version and is rg avaliable
- [x] validate environment in runtime
- [x] make the set wimdow option be a function
- [x] disable winbar
- [x] when preview files set the cursor to the begin of line
- [x] quit rpc client
- [x] vim resize event
- [x] main window quit event
- [x] when restart the fzf using runtime_ctx.qeury
- [ ] keymap scroll preview window

Now, it's a simple fzf wrapper for neovim.

- [x] fzf-lua like `files`
- [x] fzf-lua like `git_files` only provide this command for git, other functionalities i think vim-fugitive plugin doing them better
- [x] edit file funtion no selected case

- [ ] fzf-lua like `grep`
  + `grep_cword` maybe not provide directly, let the user write a simple function to do this
  + `grep_curbuf` this may useful, even through i don't use it very often
  + [ ] only the deleted files are has some mark
- [ ] fzf-lua like `helptags` this command is very useful actually

##### low priority

- [ ] fzf-lua like `blines`
- [ ] tags(ctags, gnu-global) not only simple filter raw tags
  + `ctags` (function definitions, methods, global variables)
  + `gtags` gnu-global (function definitions, methods, global variables)
- [ ] lsp
  + `lsp_docmuent_symbols` filter only useful symbols (function definitions, methods, global variables) only for current buffer

- `CFLAGS="-DFFMK_DUMP_LOG" make`
------------------------------------------------------------------------------

- `undotree` and `onlysearch` should not open when in command line window
- `onlysearch` --max-columns=4096
- `undotree` make the cursor always in the middle of the undotree window
