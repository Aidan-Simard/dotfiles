return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    ensure_installed = {
      "gopls",
      "lua_ls",
      "basedpyright",
      "elixirls"
    },
    automatic_enable = true
  },
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
  },
}
