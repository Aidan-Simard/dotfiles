local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<C-p>', builtin.git_files, {})
vim.keymap.set('n', '<leader>ps', builtin.live_grep, {})

local telescope = require('telescope')
telescope.setup {
    pickers = {
        find_files = {
            hidden = true,
            file_ignore_patterns = { ".git/", ".cache", "%.o", "%.a", "%.out", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip", "node_modules/", "venv/" }
        },
        live_grep = {
            additional_args = function(opts)
                return { "--hidden" }
            end,
            file_ignore_patterns = { ".git/", ".cache", "%.o", "%.a", "%.out", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip", "node_modules/", "venv/" }
        }
    }
}
