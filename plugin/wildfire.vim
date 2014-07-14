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

let g:wildfire_objects =
    \ get(g:, "wildfire_objects", split("ip i) i] i} i' i\" it"))

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")


" Mappings
" =============================================================================

vmap <silent> <Plug>(wildfire-water) :<C-U>call wildfire#Water(v:count1)<CR>

nmap <silent> <Plug>(wildfire-fuel) :<C-U>call wildfire#Start(v:count1, g:wildfire_objects)<CR>
omap <silent> <Plug>(wildfire-fuel) :<C-U>call wildfire#Start(v:count1, g:wildfire_objects)<CR>
vmap <silent> <Plug>(wildfire-fuel) :<C-U>call wildfire#Fuel(v:count1)<CR>

for var in keys(g:)
    let label = matchstr(var, '\v(wildfire_objects_)@<=(.+)')
    if !empty(label)
        exe "nmap <silent> <Plug>(wildfire-fuel:".label.") :<C-U>call wildfire#Start(v:count1, g:".var.")<CR>"
        exe "vmap <silent> <Plug>(wildfire-fuel:".label.") :<C-U>call wildfire#Fuel(v:count1)<CR>"
    end
endfor

if !hasmapto('<Plug>(wildfire-fuel)')
    exe "map" g:wildfire_fuel_map "<Plug>(wildfire-fuel)"
end
if !hasmapto('<Plug>(wildfire-water)')
    exe "vmap" g:wildfire_water_map "<Plug>(wildfire-water)"
end


" Autocommands
" =============================================================================

fu! DisableWildfire()
    sil! exec "nnoremap <buffer> " . g:wildfire_fuel_map . " " . g:wildfire_fuel_map
endfu

augroup wildfire
    au!
    " Disable Wildfire inside buffers with the `buftype` option set (See :h 'buftype')
    au BufReadPost * if !empty(&bt) | call DisableWildfire() | endif
    " Disable Wildfire inside the command-line window
    au CmdWinEnter * call DisableWildfire()
    " Disable Wildfire inside quickfix buffers
    au FileType qf call DisableWildfire()
augroup END


let &cpo = s:save_cpo
unlet s:save_cpo
