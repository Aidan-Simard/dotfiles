return {
  'nvim-telescope/telescope.nvim', tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim' },

  config = function()
    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
    vim.keymap.set('n', '<C-p>', builtin.git_files, {})
    vim.keymap.set('n', '<leader>ps', builtin.live_grep, {})

    local telescope = require('telescope')
    local ignore = {
      ".git/",
      ".cache",
      "%.o",
      "%.a",
      "%.out",
      "%.class",
      "%.pdf",
      "%.mkv",
      "%.mp4",
      "%.zip",
      "node_modules/",
      "venv/"
    }

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
}
