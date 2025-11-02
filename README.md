# ffmk(fuzzy finder minimal kit)

Now, it's a simple fzf wrapper for neovim.

- [ ] only telescope.nvim like ui layout
- [ ] fzf-lua like `files`
- [ ] fzf-lua like `buffers` (not very useful)
- [ ] fzf-lua like `blines`
- [ ] fzf-lua like `grep`
  + `grep_cword` maybe not provide directly, let the user write a simple function to do this
  + `grep_curbuf` this may useful, even through i don't use it very often
- [ ] fzf-lua like `git_files` only provide this command for git, other functionalities i think vim-fugitive plugin doing them better
- [ ] fzf-lua like `helptags` this command is very useful actually
- [ ] tags(ctags, gnu-global) not only simple filter raw tags
  + `ctags` (function definitions, methods, global variables)
  + `gtags` gnu-global (function definitions, methods, global variables)
- [ ] lsp
  + `lsp_docmuent_symbols` filter only useful symbols (function definitions, methods, global variables) only for current buffer
  + `lsp_code_action` if this complex, do not support that
