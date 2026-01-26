# ffmk(fuzzy finder minimal kit)

> [!CAUTION]
> Only works on Linux systems.

**ffmk** is a minimal Neovim fuzzy-finder powered by [fzf](https://github.com/junegunn/fzf), offering only essential pickers.

[![preview](https://github.com/user-attachments/assets/33fa940b-715b-494f-b3eb-ed7ea31f5fa0)](https://github.com/user-attachments/assets/feda2f88-0a82-47d2-805b-3db7b5b0b1cc)

## Requirements

- nvim 0.11.0 or above
- `make` and `gcc`
- [fzf](https://github.com/junegunn/fzf)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [fd](https://github.com/sharkdp/fd) optional
- [universal ctags](https://github.com/universal-ctags/ctags) required by `ctags`
- [GNU global](https://www.gnu.org/software/global/) required by `gnu_global`

## Features

- [Telescope](https://github.com/nvim-telescope/telescope.nvim)-like UI
- Minimal and lightweight (~1300 lines of Lua and ~550 lines of C)
- Supports widely used pickers: `files`, `grep`, and `helptags`
- Provides a different `ctags` implementation compared to other fuzzy finders
- Supports a `gnu_global` picker based on GNU’s `global` tagging system

## Non-Features

- No fancy icons
- Portability is not a primary goal, but the code follows a [suckless](https://suckless.org/) philosophy and is not so difficult to patch

## TODO

- [ ] lsp
  + `lsp_docmuent_symbols` filters only useful symbols (function definitions, methods, global variables) only for current buffer

## Download and Install

Using Neovim's built-in package manager:

```sh
mkdir -p ~/.config/nvim/pack/github/start/
cd ~/.config/nvim/pack/github/start/
git clone https://github.com/jiaoshijie/ffmk.git
cd ffmk
make
```
- `make help` for more information

## Usage

### Configuration

Default settings are defined in [config.lua](./lua/ffmk/config.lua).

Highlight groups are defined in [plugin/ffmk.lua](./plugin/ffmk.lua).

An example of how to configure this plugin can be found in [ffmk.lua](https://github.com/jiaoshijie/nvim/blob/minimal/after/plugin/ffmk.lua).

### Providers

| Providers    | List                                               |
| :----:       | :----:                                             |
| `files`      | List files                                         |
| `grep`       | Search with `rg`                                   |
| `helptags`   | list neovim's helptags                             |
| `ctags`      | List `universal-ctags` symbols in the current file |
| `gnu_global` | gtags <sup id="a1">[1](#gnu_global)</sup>                         |

#### Commen Default Keymaps

`fzf` running in a terminal session, terminal mode is like insert mode.

| Mode     | Key           | Action                     |
| :----:   | :----:        | :----:                     |
| Normal   | `<C-[>`/`ESC` | Quit                       |
| Terminal | `<C-c>`       | Quit                       |
| Terminal | `<A-p>`       | Toggle preview window      |
| Terminal | `<C-u>`       | Scroll preview window up   |
| Terminal | `<C-d>`       | Scroll preview window down |

#### files

How to use `files` provider listing **git files** can be found in above example config.

| Mode     | Key     | Action                          |
| :----:   | :----:  | :----:                          |
| Terminal | `<A-h>` | Toggle hidden files             |
| Terminal | `<A-i>` | Toggle ignore files             |
| Terminal | `<A-f>` | Toggle follow for soft symlinks |

#### grep

| Mode     | Key     | Action                          |
| :----:   | :----:  | :----:                          |
| Terminal | `<A-h>` | Toggle hidden files             |
| Terminal | `<A-i>` | Toggle ignore files             |
| Terminal | `<A-f>` | Toggle follow for soft symlinks |
| Terminal | `<A-c>` | Toggle case sensitive           |
| Terminal | `<A-w>` | Toggle match whole word         |
| Terminal | `<A-F>` | Toggle search for raw string    |

#### helptags

Nothing special here.

#### ctags

ffmk’s `ctags` implementation parses only the current file, making it simpler and easier to understand.

For more advanced tag usage, consider the `GNU global` a simple yet powerful tagging system.

#### gnu_global

| Mode     | Key     | Action                          |
| :----:   | :----:  | :----:                          |
| Terminal | `<A-c>` | Toggle case sensitive           |
| Terminal | `<A-F>` | Toggle search for raw string    |

- [GNU global tutorial](https://www.gnu.org/software/global/globaldoc_toc.html)
- [how to configure gtags using ctags](https://xenodium.com/gnu-global-ctags-and-emacs-setup)
- [my gtags.conf](https://github.com/jiaoshijie/dots/blob/main/gtags/gtags.conf)

`gtags/global` provide a convenient way to query tags.

It supports:
1. Find a symbol’s definition
2. Find all references to a symbol
3. List all symbols in a file (limited; `ctags` can provide symbol type)

How do i config `gnu_global` can be found in the above example.

## Bug Reports

Bug reports are welcome.

## License

**MIT**
