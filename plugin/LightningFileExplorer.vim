lua require('LightningFileExplorer.lua')

augroup LightningFileExplorer
    au!
    au BufDelete * lua LiFE.clean()
augroup END

command -nargs=* LiFE lua LiFE.open('<args>')
