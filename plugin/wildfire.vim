" =============================================================================
" File: wildfire.vim
" Description: Fast selection of the closest text object delimited any of ', ", ), ] or }
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================


" Init
" =============================================================================

if exists("g:loaded_wildfire") || &cp
    finish
endif
let g:loaded_wildfire = 1


" Settings
" =============================================================================

let g:wildfire_delimiters =
    \ get(g:, "wildfire_delimiters", ["p", ")", "]", "}", "'", '"'])

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")


" Functions
" =============================================================================

let s:delimiters = {}
let s:winners_history = []
let s:origin = []


fu! s:Wildfire(burning, water, repeat)

    if !a:repeat
        return
    endif

    if !a:burning || empty(s:origin)
        cal s:init()
    endif

    cal setpos(".", s:origin)

    if a:water
        cal s:select_smaller_block()
        return
    endif

    let winview = winsaveview()

    let candidates = {}
    for delim in keys(s:delimiters)

        let selection = "v" . s:delimiters[delim] . "i" . delim
        exe "norm! \<ESC>v\<ESC>" . selection . "\<ESC>"
        let [startline, startcol, endline, endcol] = s:get_vblock_vertices()

        cal winrestview(winview)

        if startline != endline || startcol != endcol

            let size = s:get_vblock_size(startline, startcol, endline, endcol)

            if (delim == "'" || delim == '"') && startline == endline
                let [before, after] = [getline("'<")[:startcol-3],  getline("'<")[endcol+1:]]
                let cond1 = !s:already_a_winner("v".(s:delimiters[delim]-1)."i".delim)
                let cond2 = !s:odd_quotes(delim, before) && !s:odd_quotes(delim, after)
                if cond1 && cond2
                    let candidates[size] = selection
                endif
            else
                let candidates[size] = selection
            endif

        endif

    endfor

    cal s:select_bigger_block(candidates)

    cal s:Wildfire(1, 0, a:repeat-1)

endfu


" Helpers
" =============================================================================

" to initialize state variables
fu! s:init()
    let s:origin = getpos(".")
    let s:winners_history = []
    for delim in g:wildfire_delimiters
        let s:delimiters[delim] = 1
    endfor
endfu

fu! s:select_smaller_block()
    if len(s:winners_history) > 1
        let last_winner = remove(s:winners_history, -1)
        let s:delimiters[strpart(last_winner, len(last_winner)-1, 1)] -= 1
        exe "norm! \<ESC>" . get(s:winners_history, -1)
    endif
endfu

fu! s:select_bigger_block(candidates)
    if len(a:candidates)
        let minsize = min(keys(a:candidates))
        let winner = a:candidates[minsize]
        let [startcol, endcol] = [a:candidates[minsize], a:candidates[minsize]]
        let s:winners_history = add(s:winners_history, winner)
        let s:delimiters[strpart(winner, len(winner)-1, 1)] += 1
        exe "norm! \<ESC>" . winner
    elseif len(s:winners_history)
        " get stuck on the last selection
        exe "norm! \<ESC>" . get(s:winners_history, -1)
    else
        exe "norm! \<ESC>"
    endif
endfu

fu! s:already_a_winner(selection)
    for winner in s:winners_history
        if winner == a:selection
            return 1
        endif
    endfor
    return 0
endfu

fu! s:odd_quotes(quote, s)
    let n = 0
    for i in range(0, strlen(a:s))
        if a:s[i] == a:quote && !(i > 0 && a:s[i-1] == "\\")
            let n += 1
        endif
    endfor
    return n % 2 != 0
endfu

fu! s:get_vblock_vertices()
    return [line("'<"), col("'<"), line("'>"), col("'>")]
endfu

fu! s:get_vblock_size(startline, startcol, endline, endcol)
    if a:startline == a:endline
        return strlen(strpart(getline("'<"), a:startcol, a:endcol-a:startcol+1))
    endif
    let size = strlen(strpart(getline("'<"), a:startcol))
    let size += strlen(strpart(getline("'>"), 0, a:endcol))
    let size += winwidth(0) * abs(a:startline - a:endline)  " good enough
    return size
endfu


" Commands and Mappings
" =============================================================================

command! -nargs=0 -range WildfireStart call s:Wildfire(0, 0, <line2> - <line1> + 1)
command! -nargs=0 -range WildfireFuel call s:Wildfire(1, 0, 1)
command! -nargs=0 -range WildfireWater call s:Wildfire(1, 1, 1)

exec "nnoremap <silent> " . g:wildfire_fuel_map . " :WildfireStart<CR>"
exec "vnoremap <silent> " . g:wildfire_fuel_map . " :WildfireFuel<CR>"
exec "vnoremap <silent> " . g:wildfire_water_map . " :WildfireWater<CR>"
