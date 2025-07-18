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
