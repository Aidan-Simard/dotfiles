require('rose-pine').setup({
    variant = 'auto',
    highlight_groups = {
        ColorColumn = { bg = 'surface' },
        StatusLine = { fg = "love", bg = "love", blend = 10 },
        StatusLineNC = { fg = "subtle", bg = "surface" },
    },
})


function Colors(color)
    color = color or "rose-pine"
    vim.cmd.colorscheme(color)
end

Colors()
