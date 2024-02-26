local lsp = require('lsp-zero')

lsp.preset('recommended')

require('mason').setup({})
require('mason-lspconfig').setup({
    ensure_installed = {
        'gopls',
        'lua_ls',
        'pylsp',
        'html',
        'cssmodules_ls',
        'tailwindcss',
        'elixirls',
        'templ'
    }
})

lsp.ensure_installed({
    'gopls',
    'lua_ls',
    'pylsp',
    'html',
    'cssmodules_ls',
    'tailwindcss',
    'elixirls',
    'templ'
})

lsp.format_on_save({
    format_opts = {
        async = false,
        timeout_ms = 10000,
    },
    servers = {
        ['lua_ls'] = { 'lua' },
        ['gopls'] = { 'go' },
        ['html'] = { 'html', 'htmldjango' },
        ['pyright'] = { 'python' },
        ['cssmodules_ls'] = { 'css' },
        ['tailwindcss'] = { 'html', 'htmldjango' },
        ['elixirls'] = { 'ex', 'exs' },
        ['templ'] = { 'templ' },
        ['tsserver'] = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }
    }
})

require('lspconfig').tailwindcss.setup {}

local cmp = require('cmp')
local cmp_select = { behavior = cmp.SelectBehavior.Select }
local cmp_mappings = lsp.defaults.cmp_mappings({
    ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
    ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
    ['<C-y>'] = cmp.mapping.confirm({ select = true }),
    ['<C-Space>'] = cmp.mapping.complete(),
})

lsp.set_preferences({
    sign_icons = {}
})

lsp.setup_nvim_cmp({
    mapping = cmp_mappings
})

lsp.on_attach(function(client, bufnr)
    local opts = { buffer = bufnr, remap = false }

    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
    vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
end)

-- additional filetypes
vim.filetype.add({
    extension = {
        templ = "templ",
    },
})

lsp.setup()
