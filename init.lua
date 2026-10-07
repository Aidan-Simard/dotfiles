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
      { out,                            "WarningMsg" },
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
      'nvim-telescope/telescope.nvim',
      -- no tag: 0.1.8 predates nvim-treesitter main compat (and the nvim 0.12
      -- deprecation fixes); lazy-lock pins the commit
      dependencies = { 'nvim-lua/plenary.nvim' },

      config = function()
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
        vim.keymap.set('n', '<C-p>', builtin.git_files, {})
        vim.keymap.set('n', '<leader>ps', builtin.live_grep, {})

        local telescope = require('telescope')
        local ignore = { ".git/", ".cache", "%.o", "%.a", "%.out", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip",
          "node_modules/", "venv/" }

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
      -- main branch rewrite; requires Neovim >= 0.12. Keep in sync with
      -- NVIM_VER in apply.sh.
      "nvim-treesitter/nvim-treesitter",
      branch = 'main',
      lazy = false,
      build = ":TSUpdate",

      config = function()
        -- parsers and query symlinks install into stdpath('data')/site
        require("nvim-treesitter").setup {}

        require("nvim-treesitter").install {
          "lua",
          "python",
          "bash",
          "go",
          "vim",
          "vimdoc",
          "query",
          "markdown",
          "markdown_inline",
          "html",
          "htmldjango",
          "css",
          "javascript",
          "typescript",
          "tsx",
          "svelte",
          "json",
          "yaml",
          "c",
          "make",
          "gomod",
          "regex",
          "requirements",
          "ssh_config",
          "terraform",
          "pem",
        }

        -- no highlight/indent modules on main: drive both from FileType.
        -- vim.treesitter.start() also disables legacy vim regex highlighting,
        -- matching the old additional_vim_regex_highlighting = false.
        local installing = {}
        vim.api.nvim_create_autocmd("FileType", {
          callback = function(ev)
            local lang = vim.treesitter.language.get_lang(ev.match) or ev.match

            pcall(vim.treesitter.start, ev.buf, lang)

            -- get_indent() returns 0 without an indents query, which would
            -- flatten indentation, so only set it where the query exists
            local ok, indent_query = pcall(vim.treesitter.query.get, lang, "indents")
            if ok and indent_query then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end

            -- master branch's auto_install, emulated: fetch a parser the first
            -- time a filetype needs one that isn't installed yet.
            -- language.add() returns nil+err rather than throwing
            local added = select(2, pcall(vim.treesitter.language.add, lang))
            if not added and not installing[lang] then
              local parsers_ok, parsers = pcall(require, "nvim-treesitter.parsers")
              if parsers_ok and parsers[lang] then
                installing[lang] = true
                require("nvim-treesitter").install({ lang }):await(function()
                  installing[lang] = nil
                  pcall(vim.treesitter.start, ev.buf, lang)
                end)
              end
            end
          end,
        })
      end
    },
    {
      "olimorris/codecompanion.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
      opts = {
        chat = {
          adapter = {
            name = "copilot",
            model = "gpt-4.1",
          },
        },
        opts = {
          log_level = "DEBUG",
        },
      },
    },
    {
      "mason-org/mason-lspconfig.nvim",
      opts = {
        ensure_installed = {
          "lua_ls",
          "ruff",
          "ty"
        }
      },
      dependencies = {
        { "mason-org/mason.nvim", opts = {} },
        "neovim/nvim-lspconfig",
      },
    },
    {
      "OXY2DEV/markview.nvim",
      lazy = false,
    }
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
  'autocmd FileType lua,yaml,htmldjango,html,javascript,typescript,json,javascriptreact,typescriptreact,svelte :setlocal sw=2 ts=2 sts=2')

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

-- border around floating windows (LSP hover, diagnostics)
vim.o.winborder = "single"

-- write to swap every 0.5s
vim.opt.updatetime = 500

-- line at 80 chars
vim.opt.colorcolumn = "80"

-- use thin cursor when in insert mode
vim.cmd('autocmd VimLeave * set guicursor= | call chansend(v:stderr, "\x1b[ q")')

-- auto format on save if possible
vim.cmd [[autocmd BufWritePre * lua vim.lsp.buf.format()]]

-- setup clipboard for wsl
vim.o.clipboard = "unnamedplus"

-- always open splits right
vim.opt.splitright = true
vim.opt.splitbelow = true

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
