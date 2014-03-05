" =============================================================================
" File: wildfire.vim
" Description: Smart selection of the closest text object
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================

" Init
" =============================================================================

if exists("g:loaded_wildfire")
    finish
endif
let g:loaded_wildfire = 1

let s:save_cpo = &cpo
set cpo&vim


" Settings
" =============================================================================

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")


" Commands and Mappings
" =============================================================================

exe "nnoremap <silent> " . g:wildfire_fuel_map . " :<C-U>call wildfire#start(v:count1)<CR>"
exe "vnoremap <silent> " . g:wildfire_fuel_map . " :<C-U>call wildfire#fuel(v:count1)<CR>"
exe "vnoremap <silent> " . g:wildfire_water_map . " :<C-U>call wildfire#water()<CR>"


" Autocommands
" =============================================================================

augroup wildfire
    au!

    " Disable Wildfire inside help or quickfix buffers
    au BufReadPost,CmdWinEnter * if !empty(&bt) |
        \ sil! exec "nnoremap <buffer> " . g:wildfire_fuel_map . " " . g:wildfire_fuel_map |
        \ endif

augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
