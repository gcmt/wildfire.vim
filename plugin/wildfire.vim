" =============================================================================
" File: wildfire.vim
" Description: Fast selection of the closest text object delimited any of ', ", ), ] or }
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================


" INIT
" =============================================================================

if exists("g:loaded_wildfire") || &cp
    finish
endif
let g:loaded_wildfire = 1


let s:wildfire_delimiters = {}
for delim in get(g:, "wildfire_delimiters", ['"', "'", ")", "]", "}", "t"])
    let s:wildfire_delimiters[delim] = 1
endfor

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")


" FUNCTIONS
" =============================================================================

" variables that provide some sort of statefulness between function calls
let s:delimiters = {}
let s:winners_history = []
let s:origin = []


fu! s:Wildfire(burning, water, repeat)

    if !a:repeat
        return
    endif

    if !a:burning || empty(s:origin) || s:origin[1] != line(".")
        cal s:init()
    endif

    cal setpos(".", s:origin)

    if a:water
        cal s:prev()
        return
    endif

    let winview = winsaveview()
    let [curline, curcol] = [s:origin[1], s:origin[2]]

    norm! "\<ESC>"
    cal setpos(".", s:origin)

    let candidates = {}
    for delim in keys(s:delimiters)

        let selection = "v" . s:delimiters[delim] . "i" . delim
        exe "norm! v\<ESC>" . selection . "\<ESC>"

        let [startline, startcol] = [line("'<"), col("'<")]
        let [endline, endcol] = [line("'>"), col("'>")]
        let before = getline("'<")[:startcol-3]
        let after = getline("'<")[endcol+1:]

        cal winrestview(winview)

        if startline == endline && startcol != endcol && curcol >= startcol && curcol <= endcol
            let size = strlen(strpart(getline("'<"), startcol, endcol-startcol+1))
            let cond1 = delim == "'" || delim == '"'
            let cond2 = !s:already_a_winner("v".(s:delimiters[delim]-1)."i".delim)
            let cond3 = !s:odd_quotes(delim, before) && !s:odd_quotes(delim, after)
            if !cond1 || (cond1 && cond2 && cond3)
                let candidates[size] = [selection, startcol, endcol]
            endif
        endif

    endfor

    cal s:next(candidates)

    cal s:Wildfire(1, 0, a:repeat-1)

endfu

fu! s:init()
    let s:origin = getpos(".")
    let s:delimiters = copy(s:wildfire_delimiters)
    let s:winners_history = []
endfu

fu! s:prev()
    if len(s:winners_history) > 1
        " select the previous closest text object
        let exwinner = remove(s:winners_history, -1)
        let s:delimiters[strpart(exwinner[0], len(exwinner[0])-1, 1)] -= 1
        exe "norm! \<ESC>" . get(s:winners_history, -1)[0]
    endif
endfu

fu! s:next(candidates)
    if len(a:candidates)
        " select the next closest text object
        let minsize = min(keys(a:candidates))
        let winner = a:candidates[minsize][0]
        let startcol = a:candidates[minsize][1]
        let endcol = a:candidates[minsize][2]
        let s:winners_history = add(s:winners_history, [winner, minsize, startcol, endcol])
        let s:delimiters[strpart(winner, len(winner)-1, 1)] += 1
        exe "norm! \<ESC>" . winner
    elseif len(s:winners_history)
        " get stuck on the last selection
        exe "norm! \<ESC>" . get(s:winners_history, -1)[0]
    endif
endfu

fu! s:already_a_winner(selection)
    for winner in s:winners_history
        if winner[0] == a:selection
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


" COMMANDS & MAPPINGS
" =============================================================================

command! -nargs=0 -range WildfireStart call s:Wildfire(0, 0, <line2> - <line1> + 1)
command! -nargs=0 -range WildfireFuel call s:Wildfire(1, 0, 1)
command! -nargs=0 -range WildfireWater call s:Wildfire(1, 1, 1)

exec "nnoremap <silent> " . g:wildfire_fuel_map . " :WildfireStart<CR>"
exec "vnoremap <silent> " . g:wildfire_fuel_map . " :WildfireFuel<CR>"
exec "vnoremap <silent> " . g:wildfire_water_map . " :WildfireWater<CR>"
