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

" Colors
" =============================================================================

fu! s:setup_colors()
    hi default link WildfireMark WarningMsg
    hi default link WildfirePrompt String
    hi default link WildfireShade Comment
endfu

cal s:setup_colors()

" Settings
" =============================================================================

let g:wildfire_objects =
    \ get(g:, "wildfire_objects", split("ip i) i] i} i' i\" it"))

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")

let g:wildfire_prompt =
    \ get(g:, "wildfire_prompt", " Target: ")

let g:wildfire_marks =
    \ get(g:, "wildfire_marks", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

" Mappings
" =============================================================================

vnoremap <silent> <Plug>(wildfire-water) :<C-U>call wildfire#Water(v:count1)<CR>

nnoremap <silent> <Plug>(wildfire-quick-select) :<C-U>call wildfire#QuickSelect(g:wildfire_objects)<CR>
onoremap <silent> <Plug>(wildfire-quick-select) :<C-U>call wildfire#QuickSelect(g:wildfire_objects)<CR>

nnoremap <silent> <Plug>(wildfire-fuel) :<C-U>call wildfire#Start(v:count1, g:wildfire_objects)<CR>
onoremap <silent> <Plug>(wildfire-fuel) :<C-U>call wildfire#Start(v:count1, g:wildfire_objects)<CR>
vnoremap <silent> <Plug>(wildfire-fuel) :<C-U>call wildfire#Fuel(v:count1)<CR>

for var in keys(g:)
    let label = matchstr(var, '\v(wildfire_objects_)@<=(.+)')
    if !empty(label)
        exe "nnoremap <silent> <Plug>(wildfire-quick-select:".label.") :<C-U>call wildfire#QuickSelect(".var.")<CR>"
        exe "onoremap <silent> <Plug>(wildfire-quick-select:".label.") :<C-U>call wildfire#QuickSelect(".var.")<CR>"
        exe "nnoremap <silent> <Plug>(wildfire-fuel:".label.") :<C-U>call wildfire#Start(v:count1, ".var.")<CR>"
        exe "vnoremap <silent> <Plug>(wildfire-fuel:".label.") :<C-U>call wildfire#Fuel(v:count1)<CR>"
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

fu! s:disable_wildfire()
    sil! exec "nnoremap <buffer> " . g:wildfire_fuel_map . " " . g:wildfire_fuel_map
endfu

augroup wildfire
    au!
    " Disable Wildfire inside buffers with the `buftype` option set (See :h 'buftype')
    au BufReadPost * if !empty(&bt) | call s:disable_wildfire() | endif
    " Disable Wildfire inside the command-line window
    au CmdWinEnter * call s:disable_wildfire()
    " Disable Wildfire inside quickfix buffers
    au FileType qf call s:disable_wildfire()
    " Setup colors
    au BufWritePost .vimrc call s:setup_colors()
    au Colorscheme * call s:setup_colors()
augroup END

" =============================================================================

let &cpo = s:save_cpo
unlet s:save_cpo
