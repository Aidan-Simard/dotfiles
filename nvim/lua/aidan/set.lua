vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.autoindent = true
vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"

vim.opt.updatetime = 50

vim.opt.colorcolumn = "80"

vim.g.mapleader = " "

vim.cmd('autocmd VimLeave * set guicursor= | call chansend(v:stderr, "\x1b[ q")')
vim.cmd(
  'autocmd FileType lua,yaml,htmldjango,html,javascript,typescript,json,javascriptreact,typescriptreact :setlocal sw=2 ts=2 sts=2')
vim.cmd [[autocmd BufWritePre * lua vim.lsp.buf.format()]]

vim.filetype.add({
  pattern = {
    -- ansible playbook
    [".*/.*playbook.*.ya?ml"] = "yaml.ansible",
    [".*/.*tasks.*/.*ya?ml"] = "yaml.ansible",
    [".*/local.ya?ml"] = "yaml.ansible",
  },
})

vim.o.clipboard = "unnamedplus"
