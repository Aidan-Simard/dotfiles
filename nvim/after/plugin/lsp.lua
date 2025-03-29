local lsp = require('lsp-zero')
local lspconfig = require('lspconfig')

lsp.preset('recommended')

require('mason').setup({})
require('mason-lspconfig').setup({})

lsp.ensure_installed({
  'gopls',
  'lua_ls',
  'pylsp',
  'html',
  'pyright',
  'elixirls',
  'bashls',
  'yamlls',
  'ansiblels'
})

lsp.format_on_save({
  format_opts = {
    async = false,
    timeout_ms = 10000,
  }
})

--- lsp config setups
lspconfig.gopls.setup({
  cmd = { os.getenv("HOME") .. "/go/bin/gopls" }
})
lspconfig.htmx.setup {}
lspconfig.tailwindcss.setup {}
lspconfig.html.setup {
  filetypes = {
    'html',
    'htmldjango'
  }
}
lspconfig.eslint.setup({
  on_attach = function(client, bufnr)
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      command = "EslintFixAll",
    })
  end,
})
lspconfig.yamlls.setup({
  settings = {
    yaml = {
      schemas = {
      }
    }
  }
})
lspconfig.ansiblels.setup({})
lspconfig.elixirls.setup({})
lspconfig.lua_ls.setup({
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT"
      }
    }
  }
})

--- cmp mappings

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

lsp.setup()
