return {
  "echasnovski/mini.completion",
  version = "*", -- use branch `main` for latest development, `stable` for releases
  config = function()
    require("mini.completion").setup({
      -- Your mini.completion specific configuration
      -- See :help mini.completion.config for details
      -- Example:
      delay = {
        completion = 100, -- delay for auto-completion (ms)
        info = 100,       -- delay for displaying item info (ms)
        signature = 50,   -- delay for displaying signature help (ms)
      },
      -- You'll likely want to configure how it interacts with LSP
      -- For LSP completion, `mini.completion` will automatically use `vim.lsp.buf_request`
      -- as its first stage.
    })
  end,
}
