# ⚡ Lightning <br> &nbsp; &nbsp; ⚡ File <br> &nbsp; &nbsp; &nbsp; &nbsp; ⚡ Explorer
Lightning-fast, lightweight, Lua-powered native file explorer for Neovim.
The plugin is very basic and displays local files in lightning-like structure (i.e. tree).

##Installation
```
Plug 'zoxves/LightningFileExplorer'
```
##Usage
Basic:
`:LiFE` or `:LiFE /Path/To/` or `:lua LiFE.open('/Path/To/')`

Additional configuration for NERDTree-like panel on `Alt+\`:
```
augroup LiFE_mapping
    autocmd!
    autocmd filetype LightningFileExplorer call LiFEMapping()
augroup END

function! LiFEMapping()
    setlocal statusline=%{getcwd()}\ 
    lua LiFE.click_on_file = function(entry) vim.api.nvim_command('wincmd l | edit ' .. entry.path) end
    nmap <buffer> <2-LeftMouse> <CR>
endfunction

function! LLiFE()
    40vsplit
    \| LiFE
endfunction

noremap <silent> <M-\> :call LLiFE()<CR>
```
As you can see in example above, you can add/replace functions of the plugin. Take a look at the code. Don't be afraid, it's just around 200 lines of Lua!
