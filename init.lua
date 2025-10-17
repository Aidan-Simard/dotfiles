----------
-- lazy --
----------
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    {
      "rose-pine/neovim",
      name = "rose-pine",
      config = function()
        vim.cmd("colorscheme rose-pine")
      end
    },
    {
      'nvim-telescope/telescope.nvim', tag = '0.1.8',
      dependencies = { 'nvim-lua/plenary.nvim' },
    
      config = function()
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
        vim.keymap.set('n', '<C-p>', builtin.git_files, {})
        vim.keymap.set('n', '<leader>ps', builtin.live_grep, {})
    
        local telescope = require('telescope')
        local ignore = {".git/", ".cache", "%.o", "%.a", "%.out", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip", "node_modules/", "venv/"}
    
        telescope.setup {
            pickers = {
                find_files = {
                    hidden = true,
                    file_ignore_patterns = ignore
                },
                live_grep = {
                    additional_args = function(opts)
                        return { "--hidden" }
                    end,
                    file_ignore_patterns = ignore
                }
            }
        }
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter",
      branch = 'master',
      lazy = false,
      build = ":TSUpdate",
    
      config = function()
        require("nvim-treesitter.configs").setup {
          ensure_installed = {
            "lua",
            "python",
            "bash",
            "go",
            "vim",
            "vimdoc",
            "query"
          },
          auto_install = true,
          highlight = {
            enable = true,
            additional_vim_regex_highlighting = false
          },
          indent = {
            enable = true
          }
        }
      end
    },
  },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
})

---------
-- Set --
---------
-- relative line numbers & show current
vim.opt.nu = true
vim.opt.relativenumber = true

-- default indenting
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- modified indenting by file type
vim.cmd(
  'autocmd FileType lua,yaml,htmldjango,html,javascript,typescript,json,javascriptreact,typescriptreact :setlocal sw=2 ts=2 sts=2')

-- better indenting
vim.opt.autoindent = false
vim.opt.smartindent = false

-- don't word wrap
vim.opt.wrap = false

-- swap & undo stuff
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- disable previous search highlighting
vim.opt.hlsearch = false

-- highlight searches from /
-- CTRL-G for next, CTRL-T for prev
vim.opt.incsearch = true

vim.opt.termguicolors = true

-- keep 8 lines above/below cursor at all times
vim.opt.scrolloff = 8

vim.opt.signcolumn = "yes"

-- write to swap every 0.5s
vim.opt.updatetime = 500

-- line at 80 chars
vim.opt.colorcolumn = "80"

-- use thin cursor when in insert mode
vim.cmd('autocmd VimLeave * set guicursor= | call chansend(v:stderr, "\x1b[ q")')

-- auto format on save if possible
vim.cmd [[autocmd BufWritePre * lua vim.lsp.buf.format()]]


-----------
-- Remap --
-----------
-- set space bar as leader
vim.g.mapleader = " "

-- netrw
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- next error details
vim.keymap.set("n", "<leader>er", vim.diagnostic.goto_next, opts)

-- perform code action
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action)

-- restart lsp if using lsp-zero
vim.keymap.set("n", "<leader>lr", vim.cmd.LspRestart)
