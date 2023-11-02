local time = os.date("*t")
local variant = "auto"
if time.hour > 6 and time.hour < 18 then
    variant = "dawn"
end

require('rose-pine').setup({
    variant = variant,
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
