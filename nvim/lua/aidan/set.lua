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

-- custom file types
vim.filetype.add({
  pattern = {
    -- ansible playbook
    [".*/.*playbook.*.ya?ml"] = "yaml.ansible",
    [".*/.*tasks.*/.*ya?ml"] = "yaml.ansible",
    [".*/local.ya?ml"] = "yaml.ansible",
  },
})

-- setup clipboard for wsl
vim.o.clipboard = "unnamedplus"
