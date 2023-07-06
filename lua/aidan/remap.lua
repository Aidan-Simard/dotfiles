vim.g.mapleader = " "

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("x", "<leader>p", "\"_dP")

vim.keymap.set("n", "<leader>er", vim.diagnostic.goto_next, opts)
