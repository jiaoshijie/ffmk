# ffmk(fuzzy finder minimal kit)

- [ ] check fzf version and is rg avaliable

- preview window
  + [ ] only use the neovim's buffer to preview file (with size limitation)
  + [ ] show percentage and line number not the scrollbar

Now, it's a simple fzf wrapper for neovim.

- [ ] only telescope.nvim like ui layout (two layout)
- [ ] fzf-lua like `files`
- [ ] fzf-lua like `git_files` only provide this command for git, other functionalities i think vim-fugitive plugin doing them better

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
